// A session owns one temporary browser profile. Additional tabs share that profile's storage.
import {spawn} from "node:child_process";
import {existsSync} from "node:fs";
import {mkdtemp, readFile, realpath, rm} from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import {setTimeout as pause} from "node:timers/promises";

const previewURL = new URL("../Preview/index.html", import.meta.url).href;
const protocolTimeout = 10000;

function boundedProtocol(label,promise) {
  let timer;
  const timeout = new Promise((_,reject)=>{
    timer=setTimeout(()=>reject(Error("Browser did not respond to "+label)),protocolTimeout);
    timer.unref();
  });
  return Promise.race([promise,timeout]).finally(()=>clearTimeout(timer));
}

export async function until(label, read) {
  const end = Date.now()+10000;
  while (Date.now()<end) { if (await read()) return; await pause(50); }
  throw Error("Timed out: "+label);
}

const transientPortErrors = new Set(["ENOENT","EBUSY","EPERM","EACCES"]);
const browserSocketPath = /^\/devtools\/browser\/[\da-fA-F]{8}(?:-[\da-fA-F]{4}){3}-[\da-fA-F]{12}$/u;

export async function waitForDevToolsPort(file, read = readFile) {
  let port;
  await until("a readable, complete DevToolsActivePort file",async()=>{
    let data;
    try { data = await read(file,"utf8"); }
    catch (error) {
      if (transientPortErrors.has(error.code)) return false;
      throw error;
    }
    // Edge can expose a partially written port before it finishes the browser WebSocket UUID.
    const [number,socketPath] = data.split(/\r?\n/u);
    if (!/^[1-9]\d{0,4}$/u.test(number) || !browserSocketPath.test(socketPath ?? "")) return false;
    const candidate = Number(number);
    if (candidate>65535) return false;
    port = candidate;
    return true;
  });
  return port;
}

async function connect(address, sockets, exceptions) {
  const socket = new WebSocket(address);
  sockets.push(socket);
  await boundedProtocol("a new connection",new Promise((resolve,reject)=>{socket.onopen=resolve;socket.onerror=reject;}));
  const pending = new Map();
  let seq = 0;
  socket.onmessage = ({data})=>{
    const {id,result,error,method,params} = JSON.parse(data);
    if (method==="Runtime.exceptionThrown") exceptions.push(params.exceptionDetails.exception?.description ?? params.exceptionDetails.text);
    if (!pending.has(id)) return;
    const {resolve,reject} = pending.get(id);
    pending.delete(id);
    if (error) reject(Error(error.message)); else resolve(result);
  };
  socket.onclose = ()=>{for (const task of pending.values()) task.reject(Error("Browser closed")); pending.clear();};
  const send = (method,params={})=>boundedProtocol(method,new Promise((resolve,reject)=>{
    if (socket.readyState!==WebSocket.OPEN) { reject(Error("Browser closed before "+method)); return; }
    const id=++seq;
    pending.set(id,{resolve,reject});
    socket.send(JSON.stringify({id,method,params}));
  }));
  const evaluate = async expression=>{
    const result = await send("Runtime.evaluate",{expression,returnByValue:true,awaitPromise:true});
    if (result.exceptionDetails) throw Error(result.exceptionDetails.exception?.description ?? result.exceptionDetails.text);
    return result.result.value;
  };
  await send("Runtime.enable");
  const find = selector=>"document.querySelector("+JSON.stringify(selector)+")";
  const visible = selector=>evaluate("Boolean("+find(selector)+"?.getClientRects().length)");
  const click = async selector=>{
    await until(selector,()=>visible(selector));
    await evaluate(find(selector)+".click()");
  };
  const input = async (selector,value)=>{
    await until(selector,()=>visible(selector));
    await evaluate("{const el="+find(selector)+";el.value="+JSON.stringify(value)+";for(const type of ['input','change']) el.dispatchEvent(new Event(type,{bubbles:true}));}");
  };
  const tab = async id=>{
    const title={today:"오늘",journal:"일지",coach:"코치"}[id];
    await click('[data-tab="'+id+'"]');
    await until("opened "+title,()=>evaluate(
      find('[data-tab="'+id+'"][aria-current="page"]')+'!==null && document.querySelector("#screen h2")?.textContent.trim()==='+JSON.stringify(title)));
  };
  const waitForDocumentChange = async (previous, requireScreen = true)=>{
    await until("new document and restored screen",async()=>{
      try {
        return await evaluate("performance.timeOrigin!=="+previous+" && document.readyState==='complete'"+(requireScreen ? " && !!document.querySelector('#screen h2')" : ""));
      } catch (error) {
        if (/execution context|context with specified id/i.test(error.message)) return false;
        throw error;
      }
    });
  };
  const reload = async ({requireScreen = true} = {})=>{
    const previous=await evaluate("performance.timeOrigin");
    await send("Page.reload");
    await waitForDocumentChange(previous,requireScreen);
  };
  return {send,evaluate,click,input,tab,reload,waitForDocumentChange,visible,action:name=>click('[data-action="'+name+'"]'),
    value:selector=>evaluate(find(selector)+"?.value"),
    stored:()=>evaluate("JSON.parse(localStorage.getItem('body-note-demo.v1'))")};
}

export async function withPreview(run, {binary: requestedBinary, onBrowserReady, afterRelaunch} = {}) {
  const binary = requestedBinary ?? [process.env.WORKOUT_TEST_BROWSER, process.env.CHROME_BIN,
    "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe",
    "C:/Program Files/Google/Chrome/Application/chrome.exe",
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    "/Applications/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing",
    "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge","/usr/bin/google-chrome","/usr/bin/chromium"]
    .find(candidate => candidate && existsSync(candidate));
  if (!binary) throw Error("Set WORKOUT_TEST_BROWSER to an installed Chrome or Edge executable.");
  const temporary = await realpath(os.tmpdir());
  const profile = await mkdtemp(path.join(temporary,"workout-preview-"));
  try {
    const result = await runPreviewSession(binary,profile,run,onBrowserReady);
    if (afterRelaunch) {
      // Edge may leave the old debugging port in its profile after a graceful shutdown.
      await rm(path.join(profile,"DevToolsActivePort"),{force:true});
      await runPreviewSession(binary,profile,afterRelaunch);
    }
    return result;
  } finally {
    const cleanup=await realpath(profile);
    if (path.dirname(cleanup)===temporary && path.basename(cleanup).startsWith("workout-preview-")) {
      await rm(cleanup,{recursive:true,force:true,maxRetries:5,retryDelay:180});
    }
  }
}

async function runPreviewSession(binary, profile, run, onBrowserReady) {
  const browser = spawn(binary,["--headless=new","--disable-gpu","--no-first-run","--no-default-browser-check",
    "--disable-background-networking","--disable-sync","--disable-extensions","--remote-debugging-address=127.0.0.1",
    "--remote-debugging-port=0","--user-data-dir="+profile,"about:blank"],{stdio:"ignore",windowsHide:true});
  const started = new Promise((resolve, reject) => {
    browser.once("spawn", resolve);
    browser.once("error", reject);
  });
  const closed = new Promise(resolve => browser.once("close", resolve));
  const sockets = [];
  const exceptions = [];
  let app;
  try {
    await started;
    const portFile = path.join(profile, "DevToolsActivePort");
    const port = await waitForDevToolsPort(portFile);
    const endpoint = "http://127.0.0.1:" + port;
    const pages = await (await fetch(endpoint + "/json/list",{signal:AbortSignal.timeout(protocolTimeout)})).json();
    app = await connect(pages.find(item => item.type === "page").webSocketDebuggerUrl, sockets, exceptions);
    if (onBrowserReady) await onBrowserReady(app);
    await app.send("Page.navigate", {url: previewURL});
    await until("initial preview screen", () => app.visible("#screen h2"));

    async function newTab() {
      const response = await fetch(endpoint + "/json/new?" + encodeURIComponent(previewURL),
        {method:"PUT",signal:AbortSignal.timeout(protocolTimeout)});
      if (!response.ok) throw Error("Could not open a preview tab: " + response.status);
      const page = await response.json();
      const tab = await connect(page.webSocketDebuggerUrl, sockets, exceptions);
      await until("initial screen in new tab", () => tab.visible("#screen h2"));
      return tab;
    }

    const result = await run({app, newTab});
    if (exceptions.length) throw Error("Uncaught browser errors:\n" + exceptions.join("\n"));
    return result;
  } finally {
    if (app) await app.send("Browser.close").catch(() => {});
    for (const socket of sockets) socket.close();
    await Promise.race([closed, pause(1500, undefined, {ref: false})]);
    if (browser.pid && browser.exitCode===null && browser.signalCode===null) {
      browser.kill();
      await Promise.race([closed, pause(1500, undefined, {ref: false})]);
    }
  }
}
