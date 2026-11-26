const assert = require("node:assert/strict");
const {test} = require("node:test");

const browserHelpers = import("../../Scripts/preview-browser.mjs");
const socketPath = "/devtools/browser/452cc86d-24d4-4286-b902-3da9c08c042e";
const validFile = "54218\r\n"+socketPath;
const osError = code => Object.assign(new Error(code),{code});

test("Edge startup waits for shared file access and for both complete DevToolsActivePort lines",async()=>{
  const {waitForDevToolsPort} = await browserHelpers;
  const snapshots = [
    ...["ENOENT","EBUSY","EPERM","EACCES"].map(osError),
    "5", "54218\n", "54218\n/devtools/browser/", validFile.slice(0,-1),
    validFile.replace("/browser/","/page/"), validFile
  ];
  let reads = 0;
  const port = await waitForDevToolsPort("profile/DevToolsActivePort",async(file,encoding)=>{
    assert.equal(file,"profile/DevToolsActivePort");
    assert.equal(encoding,"utf8");
    assert.ok(reads < snapshots.length);
    const snapshot = snapshots[reads++];
    if (snapshot instanceof Error) throw snapshot;
    return snapshot;
  });
  assert.equal(port,54218);
  assert.equal(reads,snapshots.length);
});

test("DevTools accepts TCP ports 1 through 65535 with a browser WebSocket path",async()=>{
  const {waitForDevToolsPort} = await browserHelpers;
  await Promise.all(["0","65536","123456","-1","1e3","12.5","0x48"].map(async number=>{
    let reads=0;
    const read = async()=>{
      reads++;
      return reads===1 ? number+"\n"+socketPath : validFile;
    };
    assert.equal(await waitForDevToolsPort("port",read),54218);
    assert.equal(reads,2);
  }));
  for (const number of [1,65535]) {
    assert.equal(await waitForDevToolsPort("port",async()=>number+"\n"+socketPath+"\n"),number);
  }
});

test("permanent DevToolsActivePort read errors are surfaced on the first attempt",async()=>{
  const {waitForDevToolsPort} = await browserHelpers;
  const problem = osError("ENOTDIR");
  let reads=0;
  await assert.rejects(waitForDevToolsPort("port",async()=>{reads++; throw problem;}),error=>error===problem);
  assert.equal(reads,1);
});
