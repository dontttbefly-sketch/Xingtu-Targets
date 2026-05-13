import { describe, expect, it, vi } from "vitest";
import { fireEvent, render, screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import App from "../src/App";

function getTransformScale(transform: string | null): number {
  const match = transform?.match(/scale\(([\d.]+)\)/);
  return match ? Number(match[1]) : Number.NaN;
}

describe("Starfield Goals app", () => {
  it("opens the data vault and shows local save details", async () => {
    const user = userEvent.setup();
    render(<App />);

    await user.click(screen.getByRole("button", { name: "数据舱" }));

    const panel = screen.getByRole("complementary", { name: "数据舱" });
    expect(panel).toBeInTheDocument();
    expect(within(panel).getByText("本地数据已保存")).toBeInTheDocument();
    expect(within(panel).getByText("目标 0")).toBeInTheDocument();
    expect(within(panel).getByRole("button", { name: "导出备份" })).toBeInTheDocument();
    expect(within(panel).getByRole("button", { name: "导入备份" })).toBeInTheDocument();
  });

  it("imports a valid backup from the data vault", async () => {
    const user = userEvent.setup();
    vi.spyOn(window, "confirm").mockReturnValue(true);
    render(<App />);

    await user.click(screen.getByRole("button", { name: "数据舱" }));

    const backup = {
      app: "starfield-goals",
      schemaVersion: 1,
      exportedAt: "2026-05-11T10:00:00.000Z",
      state: {
        version: 1,
        goals: [
          {
            id: "goal-imported",
            title: "导入的恒星",
            startDate: "2026-05-11",
            status: "active",
            createdAt: "2026-05-11T10:00:00.000Z",
            updatedAt: "2026-05-11T10:00:00.000Z"
          }
        ],
        routines: [],
        tasks: [],
        checkIns: []
      }
    };
    const file = new File([JSON.stringify(backup)], "backup.json", { type: "application/json" });

    fireEvent.change(screen.getByLabelText("选择备份文件"), { target: { files: [file] } });

    expect(await screen.findByRole("button", { name: "进入 导入的恒星" })).toBeInTheDocument();
    expect(screen.getByText("备份已导入")).toBeInTheDocument();
  });

  it("keeps the current star map when backup import fails", async () => {
    const user = userEvent.setup();
    render(<App />);

    await user.click(screen.getByRole("button", { name: "新建目标" }));
    await user.type(screen.getByLabelText("目标名称"), "保留当前恒星");
    await user.click(screen.getByRole("button", { name: "保存目标" }));
    await user.click(screen.getByRole("button", { name: "数据舱" }));

    const file = new File(["not json"], "broken.json", { type: "application/json" });

    fireEvent.change(screen.getByLabelText("选择备份文件"), { target: { files: [file] } });

    expect(await screen.findByText("导入失败")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "进入 保留当前恒星" })).toBeInTheDocument();
  });

  it("keeps goals after the app is rendered again from local storage", async () => {
    const user = userEvent.setup();
    const firstRender = render(<App />);

    await user.click(screen.getByRole("button", { name: "新建目标" }));
    await user.type(screen.getByLabelText("目标名称"), "长期保存恒星");
    await user.click(screen.getByRole("button", { name: "保存目标" }));

    await waitFor(() => expect(localStorage.getItem("starfield-goals:v1")).toContain("长期保存恒星"));

    firstRender.unmount();
    render(<App />);

    expect(screen.getByRole("button", { name: "进入 长期保存恒星" })).toBeInTheDocument();
  });

  it("creates a goal, adds a routine, checks it in, and updates the stats", async () => {
    const user = userEvent.setup();
    render(<App />);

    await user.click(screen.getByRole("button", { name: "新建目标" }));
    await user.type(screen.getByLabelText("目标名称"), "完成作品集");
    await user.type(screen.getByLabelText("完成期限"), "2026-05-31");
    await user.click(screen.getByRole("button", { name: "保存目标" }));

    await user.click(screen.getByRole("button", { name: "进入 完成作品集" }));
    await user.click(screen.getByRole("button", { name: "添加 routine" }));
    await user.type(screen.getByLabelText("routine 名称"), "每天整理一个案例");
    await user.click(screen.getByRole("button", { name: "保存 routine" }));

    await user.click(screen.getByRole("button", { name: "今晚复盘" }));
    await user.click(screen.getByRole("checkbox", { name: "每天整理一个案例" }));

    expect(screen.getAllByText("已完成 1 次").length).toBeGreaterThan(0);
    expect(screen.getAllByText("完成率 100%").length).toBeGreaterThan(0);
  });

  it("archives a completed goal into the star map", async () => {
    const user = userEvent.setup();
    render(<App />);

    await user.click(screen.getByRole("button", { name: "新建目标" }));
    await user.type(screen.getByLabelText("目标名称"), "完成晨间写作");
    await user.click(screen.getByRole("button", { name: "保存目标" }));
    await user.click(screen.getByRole("button", { name: "进入 完成晨间写作" }));
    await user.click(screen.getByRole("button", { name: "标记目标完成" }));

    expect(screen.getByText("已点亮恒星")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "进入 完成晨间写作" })).toBeInTheDocument();
  });

  it("toggles today's routine completion from the goal detail row", async () => {
    const user = userEvent.setup();
    render(<App />);

    await user.click(screen.getByRole("button", { name: "新建目标" }));
    await user.type(screen.getByLabelText("目标名称"), "完成星图升级");
    await user.click(screen.getByRole("button", { name: "保存目标" }));

    await user.click(screen.getByRole("button", { name: "进入 完成星图升级" }));
    await user.click(screen.getByRole("button", { name: "添加 routine" }));
    await user.type(screen.getByLabelText("routine 名称"), "打磨星图交互");
    await user.click(screen.getByRole("button", { name: "保存 routine" }));

    await user.click(screen.getByRole("button", { name: "今日点亮 打磨星图交互" }));

    expect(screen.getAllByText("已完成 1 次").length).toBeGreaterThan(0);
    expect(screen.getAllByText("完成率 100%").length).toBeGreaterThan(0);

    await user.click(screen.getByRole("button", { name: "已点亮 打磨星图交互" }));

    expect(screen.getByText("已完成 0 次")).toBeInTheDocument();
    expect(screen.getByText("完成率 0%")).toBeInTheDocument();
  });

  it("keeps free orbits visual-only and opens a routine quick panel from the focused star", async () => {
    const user = userEvent.setup();
    render(<App />);

    await user.click(screen.getByRole("button", { name: "新建目标" }));
    await user.type(screen.getByLabelText("目标名称"), "沉浸式星图");
    await user.click(screen.getByRole("button", { name: "保存目标" }));

    await user.click(screen.getByRole("button", { name: "进入 沉浸式星图" }));
    await user.click(screen.getByRole("button", { name: "添加 routine" }));
    await user.type(screen.getByLabelText("routine 名称"), "校准行星入口");
    await user.click(screen.getByRole("button", { name: "保存 routine" }));
    await user.click(screen.getByRole("button", { name: "星图" }));

    const freeOrbit = document.querySelector(".orbit-shell");
    expect(freeOrbit).not.toBeNull();
    fireEvent.click(freeOrbit as HTMLElement);

    expect(screen.queryByText("行星信标")).not.toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: "进入 沉浸式星图" }));
    await user.click(screen.getByRole("button", { name: "查看轨道 校准行星入口" }));

    const quickPanel = screen.getByLabelText("行星信标 校准行星入口");
    expect(quickPanel).toBeInTheDocument();

    await user.click(within(quickPanel).getByRole("button", { name: "今日点亮 校准行星入口" }));

    expect(screen.getAllByText("已完成 1 次").length).toBeGreaterThan(0);
    expect(screen.getAllByText("完成率 100%").length).toBeGreaterThan(0);
  });

  it("exits the focused star when clicking a routine orbit and restores top HUD immediately", async () => {
    const user = userEvent.setup();
    render(<App />);

    await user.click(screen.getByRole("button", { name: "新建目标" }));
    await user.type(screen.getByLabelText("目标名称"), "轨道返回星图");
    await user.click(screen.getByRole("button", { name: "保存目标" }));
    await user.click(screen.getByRole("button", { name: "进入 轨道返回星图" }));
    await user.click(screen.getByRole("button", { name: "添加 routine" }));
    await user.type(screen.getByLabelText("routine 名称"), "点击轨道返回");
    await user.click(screen.getByRole("button", { name: "保存 routine" }));

    const focusedOrbit = document.querySelector(".star-system.focus-near .orbit-shell");
    expect(focusedOrbit).not.toBeNull();
    fireEvent.click(focusedOrbit as HTMLElement);

    expect(screen.getByRole("region", { name: "互动星图" })).toHaveClass("focus-exiting");
    expect(screen.getByRole("region", { name: "星图总览" })).not.toHaveClass("focus-hidden");
    expect(screen.queryByText("行星信标")).not.toBeInTheDocument();
  });

  it("places the first star closer to the center of the universe", async () => {
    const user = userEvent.setup();
    render(<App />);

    await user.click(screen.getByRole("button", { name: "新建目标" }));
    await user.type(screen.getByLabelText("目标名称"), "中心恒星");
    await user.click(screen.getByRole("button", { name: "保存目标" }));

    const starSystem = screen.getByRole("button", { name: "进入 中心恒星" }).closest(".star-system");

    expect(starSystem).toHaveStyle({ left: "45%", top: "50%" });
  });

  it("spreads focused routine labels across orbit-aware left and right layers", async () => {
    const user = userEvent.setup();
    render(<App />);

    await user.click(screen.getByRole("button", { name: "新建目标" }));
    await user.type(screen.getByLabelText("目标名称"), "轨道标签布局");
    await user.click(screen.getByRole("button", { name: "保存目标" }));
    await user.click(screen.getByRole("button", { name: "进入 轨道标签布局" }));

    for (const title of ["标签一", "标签二", "标签三", "标签四", "标签五", "标签六"]) {
      await user.click(screen.getByRole("button", { name: "添加 routine" }));
      await user.type(screen.getByLabelText("routine 名称"), title);
      await user.click(screen.getByRole("button", { name: "保存 routine" }));
    }

    const labels = Array.from(document.querySelectorAll<HTMLElement>(".near-routine-label"));
    const sides = new Set(labels.map((label) => label.dataset.side));
    const captionYs = new Set(labels.map((label) => label.style.getPropertyValue("--caption-y")));

    expect(labels).toHaveLength(6);
    expect(sides).toEqual(new Set(["right", "left"]));
    expect(captionYs.size).toBeGreaterThan(1);
  });

  it("focuses the same star from a deterministic camera after free zoom changes", async () => {
    const user = userEvent.setup();
    render(<App />);

    await user.click(screen.getByRole("button", { name: "新建目标" }));
    await user.type(screen.getByLabelText("目标名称"), "固定视角");
    await user.click(screen.getByRole("button", { name: "保存目标" }));

    await user.click(screen.getByRole("button", { name: "进入 固定视角" }));

    const layer = screen.getByTestId("starfield-layer");
    const firstFocusTransform = layer.getAttribute("style");

    await user.click(screen.getByRole("button", { name: /私人航行日志/ }));
    fireEvent.wheel(screen.getByRole("region", { name: "互动星图" }), { deltaY: -240 });

    await user.click(screen.getByRole("button", { name: "进入 固定视角" }));

    expect(layer.getAttribute("style")).toEqual(firstFocusTransform);
  });

  it("pulls the focus camera farther back when a star has more routine orbits", async () => {
    const user = userEvent.setup();
    render(<App />);

    await user.click(screen.getByRole("button", { name: "新建目标" }));
    await user.type(screen.getByLabelText("目标名称"), "少轨道恒星");
    await user.click(screen.getByRole("button", { name: "保存目标" }));
    await user.click(screen.getByRole("button", { name: "进入 少轨道恒星" }));
    await user.click(screen.getByRole("button", { name: "添加 routine" }));
    await user.type(screen.getByLabelText("routine 名称"), "单一轨道");
    await user.click(screen.getByRole("button", { name: "保存 routine" }));
    await user.click(screen.getByRole("button", { name: /私人航行日志/ }));

    await user.click(screen.getByRole("button", { name: "新建目标" }));
    await user.type(screen.getByLabelText("目标名称"), "多轨道恒星");
    await user.click(screen.getByRole("button", { name: "保存目标" }));
    await user.click(screen.getByRole("button", { name: "进入 多轨道恒星" }));
    for (const title of ["第一轨道", "第二轨道", "第三轨道", "第四轨道", "第五轨道"]) {
      await user.click(screen.getByRole("button", { name: "添加 routine" }));
      await user.type(screen.getByLabelText("routine 名称"), title);
      await user.click(screen.getByRole("button", { name: "保存 routine" }));
    }
    await user.click(screen.getByRole("button", { name: /私人航行日志/ }));

    const layer = screen.getByTestId("starfield-layer");
    await user.click(screen.getByRole("button", { name: "进入 少轨道恒星" }));
    const oneRoutineScale = getTransformScale(layer.getAttribute("style"));

    await user.click(screen.getByRole("button", { name: /私人航行日志/ }));
    await user.click(screen.getByRole("button", { name: "进入 多轨道恒星" }));
    const manyRoutineScale = getTransformScale(layer.getAttribute("style"));

    expect(manyRoutineScale).toBeLessThan(oneRoutineScale);
  });

  it("renders varied soft star colors and zoom controls", async () => {
    const user = userEvent.setup();
    render(<App />);

    await user.click(screen.getByRole("button", { name: "新建目标" }));
    await user.type(screen.getByLabelText("目标名称"), "第一颗恒星");
    await user.click(screen.getByRole("button", { name: "保存目标" }));

    await user.click(screen.getByRole("button", { name: "新建目标" }));
    await user.type(screen.getByLabelText("目标名称"), "第二颗恒星");
    await user.click(screen.getByRole("button", { name: "保存目标" }));

    const firstStar = screen.getByRole("button", { name: "进入 第一颗恒星" });
    const secondStar = screen.getByRole("button", { name: "进入 第二颗恒星" });

    expect(firstStar.style.getPropertyValue("--star-core")).not.toEqual("");
    expect(secondStar.style.getPropertyValue("--star-core")).not.toEqual("");
    expect(firstStar.style.getPropertyValue("--star-core")).not.toEqual(secondStar.style.getPropertyValue("--star-core"));

    const layer = screen.getByTestId("starfield-layer");
    const initialTransform = layer.getAttribute("style");

    await user.click(screen.getByRole("button", { name: "放大星图" }));

    expect(layer.getAttribute("style")).not.toEqual(initialTransform);

    await user.click(screen.getByRole("button", { name: "重置星图缩放" }));

    expect(layer.getAttribute("style")).toEqual(initialTransform);
  });

  it("zooms the star map with the mouse wheel", async () => {
    const user = userEvent.setup();
    render(<App />);

    await user.click(screen.getByRole("button", { name: "新建目标" }));
    await user.type(screen.getByLabelText("目标名称"), "滚轮缩放");
    await user.click(screen.getByRole("button", { name: "保存目标" }));

    const layer = screen.getByTestId("starfield-layer");
    const initialTransform = layer.getAttribute("style");

    fireEvent.wheel(screen.getByRole("region", { name: "互动星图" }), { deltaY: -240 });

    expect(layer.getAttribute("style")).not.toEqual(initialTransform);
    expect(layer.getAttribute("style")).toContain("scale(1.24)");
  });

  it("zooms into the same star system beside the goal detail", async () => {
    const user = userEvent.setup();
    render(<App />);

    await user.click(screen.getByRole("button", { name: "新建目标" }));
    await user.type(screen.getByLabelText("目标名称"), "恒星聚焦");
    await user.click(screen.getByRole("button", { name: "保存目标" }));
    await user.click(screen.getByRole("button", { name: "进入 恒星聚焦" }));
    await user.click(screen.getByRole("button", { name: "添加 routine" }));
    await user.type(screen.getByLabelText("routine 名称"), "写在轨道上");
    await user.click(screen.getByRole("button", { name: "保存 routine" }));
    await user.click(screen.getByRole("button", { name: "星图" }));

    await user.click(screen.getByRole("button", { name: "进入 恒星聚焦" }));

    const focusedStar = screen.getByRole("button", { name: "进入 恒星聚焦" });
    const focusedSystem = focusedStar.closest(".star-system");

    expect(focusedSystem).toHaveClass("focus-near");
    expect(screen.queryByRole("region", { name: "聚焦恒星 恒星聚焦" })).not.toBeInTheDocument();
    expect(within(focusedSystem as HTMLElement).getByText("写在轨道上")).toBeInTheDocument();
    expect(screen.getByText("恒星档案")).toBeInTheDocument();
  });

  it("starts a unified focus transition when opening a star", async () => {
    const user = userEvent.setup();
    render(<App />);

    await user.click(screen.getByRole("button", { name: "新建目标" }));
    await user.type(screen.getByLabelText("目标名称"), "丝滑进入");
    await user.click(screen.getByRole("button", { name: "保存目标" }));

    await user.click(screen.getByRole("button", { name: "进入 丝滑进入" }));

    expect(screen.getByRole("region", { name: "互动星图" })).toHaveClass("focus-entering");
    expect(screen.getByTestId("starfield-layer")).toHaveAttribute("data-camera-mode", "focus");
    expect(screen.getByRole("button", { name: "进入 丝滑进入" }).closest(".star-system")).toHaveClass("focus-near");
    expect(screen.queryByRole("region", { name: "聚焦恒星 丝滑进入" })).not.toBeInTheDocument();
    expect(screen.getByTestId("drawer-layer")).toHaveClass("focus-transitioning");
  });

  it("starts the return camera when clicking empty focus space", async () => {
    const user = userEvent.setup();
    render(<App />);

    await user.click(screen.getByRole("button", { name: "新建目标" }));
    await user.type(screen.getByLabelText("目标名称"), "空域返回");
    await user.click(screen.getByRole("button", { name: "保存目标" }));

    await user.click(screen.getByRole("button", { name: "进入 空域返回" }));

    await user.click(screen.getByRole("region", { name: "互动星图" }));

    expect(screen.getByRole("region", { name: "互动星图" })).toHaveClass("focus-exiting");
    expect(screen.getByTestId("starfield-layer")).toHaveAttribute("data-camera-mode", "free");
  });
});
