import { expect, test } from "@playwright/test";

test("keeps locally saved goals after a page refresh", async ({ page }) => {
  await page.goto("/");

  await page.getByRole("button", { name: "新建目标", exact: true }).click();
  await page.getByLabel("目标名称").fill("长期保存星图");
  await page.getByRole("button", { name: "保存目标" }).click();

  await expect(page.getByRole("button", { name: "进入 长期保存星图" })).toBeVisible();

  await page.reload();

  await expect(page.getByRole("button", { name: "进入 长期保存星图" })).toBeVisible();
});

test("exports a backup and restores it after local storage is cleared", async ({ page }) => {
  await page.goto("/");

  await page.getByRole("button", { name: "新建目标", exact: true }).click();
  await page.getByLabel("目标名称").fill("备份恢复星图");
  await page.getByRole("button", { name: "保存目标" }).click();

  await page.getByRole("button", { name: "数据舱" }).click();
  const downloadPromise = page.waitForEvent("download");
  await page.getByRole("button", { name: "导出备份" }).click();
  const download = await downloadPromise;
  const backupPath = await download.path();
  expect(backupPath).not.toBeNull();

  await page.evaluate(() => localStorage.clear());
  await page.reload();
  await expect(page.getByRole("button", { name: "进入 备份恢复星图" })).toHaveCount(0);

  page.once("dialog", (dialog) => dialog.accept());
  await page.getByRole("button", { name: "数据舱" }).click();
  await page.getByLabel("选择备份文件").setInputFiles(backupPath!);

  await expect(page.getByText("备份已导入")).toBeVisible();
  await expect(page.getByRole("button", { name: "进入 备份恢复星图" })).toBeVisible();
});

test("keeps check-in stats after focus and review are refreshed", async ({ page }) => {
  await page.goto("/");

  await page.getByRole("button", { name: "新建目标", exact: true }).click();
  await page.getByLabel("目标名称").fill("刷新统计星图");
  await page.getByRole("button", { name: "保存目标" }).click();
  await page.getByRole("button", { name: "进入 刷新统计星图" }).click();
  await page.getByRole("button", { name: "添加 routine" }).click();
  await page.getByLabel("routine 名称").fill("刷新后仍点亮");
  await page.getByRole("button", { name: "保存 routine" }).click();
  await page.getByRole("button", { name: "今日点亮 刷新后仍点亮" }).click();

  await expect(page.getByText("已完成 1 次")).toBeVisible();

  await page.reload();
  await page.getByRole("button", { name: "进入 刷新统计星图" }).click();

  await expect(page.getByText("已完成 1 次")).toBeVisible();
  await expect(page.getByText("完成率 100%")).toBeVisible();
});

test("shows the data vault without blocking core mobile star map controls", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/");

  await page.getByRole("button", { name: "数据舱" }).click();

  await expect(page.getByRole("complementary", { name: "数据舱" })).toBeVisible();
  await expect(page.getByRole("button", { name: "导出备份" })).toBeVisible();
  await page.getByRole("button", { name: "关闭数据舱" }).click();
  await expect(page.getByRole("button", { name: "新建目标", exact: true })).toBeVisible();
});

test("creates a goal, records a routine, and reflects it in the starfield", async ({ page }) => {
  await page.goto("/");

  await page.getByRole("button", { name: "新建目标", exact: true }).click();
  await page.getByLabel("目标名称").fill("完成星图原型");
  await page.getByLabel("完成期限").fill("2026-05-31");
  await page.getByRole("button", { name: "保存目标" }).click();

  await expect(page.locator(".star-system").first()).toHaveAttribute("style", /left: 45%; top: 50%/);

  await page.getByRole("button", { name: "进入 完成星图原型" }).click();
  await page.getByRole("button", { name: "添加 routine" }).click();
  await page.getByLabel("routine 名称").fill("每天打磨一小时");
  await page.getByRole("button", { name: "保存 routine" }).click();

  await page.getByRole("button", { name: "今晚复盘" }).click();
  await page.getByRole("checkbox", { name: "每天打磨一小时" }).check();

  await expect(page.getByText("已完成 1 次")).toBeVisible();
  await expect(page.getByText("完成率 100%")).toBeVisible();
  await expect(page.locator(".star-node").first()).toBeVisible();
});

test("records today's routine from detail and supports dragging the star map", async ({ page }) => {
  await page.goto("/");

  await page.getByRole("button", { name: "新建目标", exact: true }).click();
  await page.getByLabel("目标名称").fill("升级互动星图");
  await page.getByRole("button", { name: "保存目标" }).click();
  await page.getByRole("button", { name: "进入 升级互动星图" }).click();
  await page.getByRole("button", { name: "添加 routine" }).click();
  await page.getByLabel("routine 名称").fill("观察行星轨道");
  await page.getByRole("button", { name: "保存 routine" }).click();

  await page.getByRole("button", { name: "今日点亮 观察行星轨道" }).click();

  await expect(page.getByText("已完成 1 次")).toBeVisible();
  await expect(page.getByText("完成率 100%")).toBeVisible();
  await page.getByRole("button", { name: "星图", exact: true }).click();

  const layer = page.getByTestId("starfield-layer");
  const before = await layer.getAttribute("style");
  const box = await page.getByRole("region", { name: "互动星图", exact: true }).boundingBox();
  expect(box).not.toBeNull();
  await page.mouse.move(box!.x + 320, box!.y + 300);
  await page.mouse.down();
  await page.mouse.move(box!.x + 470, box!.y + 380);
  await page.mouse.up();

  await expect(layer).not.toHaveAttribute("style", before ?? "");
  await page.getByRole("button", { name: "进入 升级互动星图" }).click();
  await expect(page.getByText("恒星档案")).toBeVisible();
});

test("opens a routine signal from an orbiting planet", async ({ page }) => {
  await page.goto("/");

  await page.getByRole("button", { name: "新建目标", exact: true }).click();
  await page.getByLabel("目标名称").fill("宇宙化界面");
  await page.getByRole("button", { name: "保存目标" }).click();
  await page.getByRole("button", { name: "进入 宇宙化界面" }).click();
  await page.getByRole("button", { name: "添加 routine" }).click();
  await page.getByLabel("routine 名称").fill("点亮行星入口");
  await page.getByRole("button", { name: "保存 routine" }).click();
  await page.getByRole("button", { name: "星图", exact: true }).click();

  await expect(page.getByRole("button", { name: "查看 routine 点亮行星入口" })).toHaveCount(0);
  await page.locator(".orbit-shell").first().dispatchEvent("click");
  await expect(page.getByText("行星信标")).toBeHidden();

  await page.getByRole("button", { name: "进入 宇宙化界面" }).click();
  await page.locator(".star-system.focus-near .orbit-shell").first().dispatchEvent("click");
  await expect(page.getByRole("region", { name: "互动星图", exact: true })).toHaveClass(/focus-exiting/);
  await expect(page.getByRole("region", { name: "星图总览", exact: true })).not.toHaveClass(/focus-hidden/);
  await expect(page.getByText("行星信标")).toBeHidden();

  await page.locator(".brand-mark").click();
  await page.getByRole("button", { name: "进入 宇宙化界面" }).click();
  await page.getByRole("button", { name: "查看轨道 点亮行星入口" }).click();

  const quickPanel = page.getByRole("complementary", { name: "行星信标 点亮行星入口" });
  await expect(quickPanel).toBeVisible();

  await quickPanel.getByRole("button", { name: "今日点亮 点亮行星入口" }).click();

  await expect(quickPanel.getByText("已完成 1 次").first()).toBeVisible();
  await expect(quickPanel.getByText("完成率 100%").first()).toBeVisible();
});

test("zooms the star map and opens the focused star detail", async ({ page }) => {
  await page.goto("/");

  await page.getByRole("button", { name: "新建目标", exact: true }).click();
  await page.getByLabel("目标名称").fill("缩放星图");
  await page.getByRole("button", { name: "保存目标" }).click();
  await page.getByRole("button", { name: "进入 缩放星图" }).click();
  await page.getByRole("button", { name: "添加 routine" }).click();
  await page.getByLabel("routine 名称").fill("轨道文字清晰");
  await page.getByRole("button", { name: "保存 routine" }).click();
  await page.getByRole("button", { name: "星图", exact: true }).click();
  await expect(page.getByRole("region", { name: "互动星图", exact: true })).not.toHaveClass(/focus-mode/);

  const layer = page.getByTestId("starfield-layer");
  const initialTransform = await layer.getAttribute("style");
  expect(initialTransform).toContain("scale(1.08)");

  await page.getByRole("button", { name: "放大星图" }).click();

  await expect(layer).toHaveAttribute("style", /scale\(1\.18\)/);

  await page.getByRole("button", { name: "重置星图缩放" }).click();

  await expect(layer).toHaveAttribute("style", /scale\(1\.08\)/);

  const mapBox = await page.getByRole("region", { name: "互动星图", exact: true }).boundingBox();
  expect(mapBox).not.toBeNull();
  await page.mouse.move(mapBox!.x + 420, mapBox!.y + 320);
  await page.mouse.wheel(0, -240);

  await expect(layer).toHaveAttribute("style", /scale\(1\.24\)/);

  await page.getByRole("button", { name: "重置星图缩放" }).click();

  const starEntry = page.getByRole("button", { name: "进入 缩放星图" });
  await expect(starEntry).toBeVisible();
  await starEntry.dispatchEvent("click");

  await expect(layer).toHaveAttribute("data-camera-mode", "focus");
  const focusedSystem = starEntry.locator("xpath=ancestor::*[contains(concat(' ', normalize-space(@class), ' '), ' star-system ')][1]");
  await expect(focusedSystem).toHaveClass(/focus-near/);
  await expect(page.getByRole("region", { name: "聚焦恒星 缩放星图" })).toBeHidden();
  await expect(focusedSystem.getByText("轨道文字清晰")).toBeVisible();
  await expect(page.getByText("恒星档案")).toBeVisible();

  await page.getByRole("region", { name: "互动星图", exact: true }).click({ position: { x: 60, y: 650 } });

  await expect(page.getByRole("region", { name: "互动星图", exact: true })).toHaveClass(/focus-exiting/);
  await expect(layer).toHaveAttribute("data-camera-mode", "free");
});

test("shows six focused routine labels in balanced orbit layers", async ({ page }) => {
  await page.goto("/");

  await page.getByRole("button", { name: "新建目标", exact: true }).click();
  await page.getByLabel("目标名称").fill("标签排布验证");
  await page.getByRole("button", { name: "保存目标" }).click();
  await page.getByRole("button", { name: "进入 标签排布验证" }).click();

  for (const title of ["标签一", "标签二", "标签三", "标签四", "标签五", "标签六"]) {
    await page.getByRole("button", { name: "添加 routine" }).click();
    await page.getByLabel("routine 名称").fill(title);
    await page.getByRole("button", { name: "保存 routine" }).click();
  }

  await page.getByRole("button", { name: "星图", exact: true }).click();
  await page.getByRole("button", { name: "进入 标签排布验证" }).click();

  await expect(page.locator(".near-routine-label")).toHaveCount(6);
  await expect(page.locator(".near-routine-label[data-side='left']")).toHaveCount(3);
  await expect(page.locator(".near-routine-label[data-side='right']")).toHaveCount(3);
  const labelFontSize = await page.getByRole("button", { name: "查看轨道 标签六" }).evaluate((element) =>
    Number.parseFloat(window.getComputedStyle(element).fontSize)
  );
  expect(labelFontSize).toBeGreaterThanOrEqual(14);
  await expect(page.getByRole("button", { name: "查看轨道 标签六" })).toBeVisible();
});
