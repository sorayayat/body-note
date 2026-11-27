import {mkdir, writeFile} from "node:fs/promises";
import path from "node:path";

const directory = process.env.WORKOUT_PREVIEW_SCREENSHOTS;

export async function preparePreviewScreenshots(app) {
  if (!directory) return;
  await mkdir(directory, {recursive: true});
  await app.send("Emulation.setDeviceMetricsOverride", {
    width: 1120, height: 940, deviceScaleFactor: 1, mobile: false
  });
}

export async function savePreviewScreenshot(app, screen) {
  if (!directory) return;
  await app.evaluate(`(async () => {
    await document.fonts.ready;
    const images = Array.from(document.images).filter(image => image.getClientRects().length);
    await Promise.all(images.map(image => image.decode()));
    await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
  })()`);
  const {data} = await app.send("Page.captureScreenshot", {format: "png", captureBeyondViewport: false});
  await writeFile(path.join(directory, screen + ".png"), Buffer.from(data, "base64"));
}
