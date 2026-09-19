#!/usr/bin/env python3
"""Captures the App Store screenshot set by driving the simulator.

    python3 AppStore/capture_screenshots.py

Writes AppStore/screenshots/iphone-65/{appearance}-{nn}-{scene}.png.

Six scenes, light and dark, on the one size App Store Connect displays for an
iPhone-only app: iPhone 11 Pro Max (1242x2688, APP_IPHONE_65). Not the 6.9"
iPhone: uploads of APP_IPHONE_67 are accepted by the API and then never
display in ASC.

Files upload in alphabetical order, so the names control the store's order:
the drawn-argument hint leads, because teaching is the product.

Inherited traps this works around (family lessons):
  * a saved game adds a Continue card to Home and shifts every tap target, so
    each appearance starts from a clean install
  * simctl has no touch injection; taps and drags go through fb-idb, driven
    from one process because chained shell invocations drop taps
  * ASC rejects screenshots with an alpha channel; everything is flattened

Shikaku-specific approach: the driver makes one safe move (tapping a 1-clue
auto-places it), then reads the app's own save to learn the board's solution,
maps grid cells to screen points from the clue elements' accessibility
frames, and lays mats by dragging corner to corner. Boards without a 1-clue
or without two uniquely-valued clues are re-rolled — gentle 5x5 boards
almost always qualify.
"""

import json
import os
import plistlib
import subprocess
import sys
import time

IDB = "/Users/kai/work/areas/ios/studio/idb-venv/bin/idb"
BUNDLE = "de.kaikunze.shikaku"
APP = "/tmp/shikaku-shots/Build/Products/Debug-iphonesimulator/Shikaku.app"
ROOT = os.path.dirname(os.path.abspath(__file__))
UNLOCK = "-ShikakuScreenshotUnlock"

# iPhone 11 Pro Max on the iOS 18.5 runtime (the 15.5 twin cannot run us).
UDID = "BCB6EC16-DCF7-4985-839A-A36B45E890F7"
EXPECTED = (1242, 2688)


def sh(*args, **kw):
    return subprocess.run(args, capture_output=True, text=True, **kw)


class Sim:
    def __init__(self, udid):
        self.udid = udid
        sh("xcrun", "simctl", "boot", udid)
        sh("xcrun", "simctl", "bootstatus", udid, "-b")
        sh(IDB, "connect", udid)

    def idb(self, *args):
        return sh(IDB, *args, "--udid", self.udid)

    def tree(self):
        out = self.idb("ui", "describe-all").stdout
        try:
            return json.loads(out)
        except json.JSONDecodeError:
            return []

    def find(self, prefix):
        for e in self.tree():
            if (e.get("AXLabel") or "").startswith(prefix):
                f = e["frame"]
                return (f["x"] + f["width"] / 2, f["y"] + f["height"] / 2)
        return None

    def clue_elements(self):
        """Centre point of every clue numeral, with its value."""
        out = []
        for e in self.tree():
            label = e.get("AXLabel") or ""
            if label.startswith("Clue "):
                f = e["frame"]
                value = int(label.split()[1].rstrip(","))
                out.append((value, (f["x"] + f["width"] / 2,
                                    f["y"] + f["height"] / 2)))
        return out

    def tap(self, point, wait=1.2):
        self.idb("ui", "tap", str(int(point[0])), str(int(point[1])))
        time.sleep(wait)

    def mat_count(self):
        """Committed mats, counted from the accessibility tree. The save
        file cannot be trusted for live state: cfprefsd flushes the plist on
        the first write and then holds later writes in memory indefinitely,
        so a file read shows a frozen early snapshot (measured here)."""
        return sum(1 for e in self.tree()
                   if (e.get("AXLabel") or "").startswith("Mat "))

    def swipe(self, a, b, wait=0.7):
        self.idb("ui", "swipe", str(int(a[0])), str(int(a[1])),
                 str(int(b[0])), str(int(b[1])), "--duration", "0.35")
        time.sleep(wait)

    def appearance(self, mode):
        sh("xcrun", "simctl", "ui", self.udid, "appearance", mode)

    def status_bar(self):
        sh("xcrun", "simctl", "status_bar", self.udid, "override",
           "--time", "9:41", "--batteryState", "charged", "--batteryLevel", "100",
           "--cellularMode", "active", "--cellularBars", "4")

    def fresh_install(self):
        """Clean install so no saved game adds a Continue card to Home."""
        sh("xcrun", "simctl", "terminate", self.udid, BUNDLE)
        sh("xcrun", "simctl", "uninstall", self.udid, BUNDLE)
        sh("xcrun", "simctl", "install", self.udid, APP)
        self.status_bar()

    def launch(self, wait=3.0):
        sh("xcrun", "simctl", "terminate", self.udid, BUNDLE)
        # The paid surfaces are unreachable otherwise: a simulator cannot buy.
        sh("xcrun", "simctl", "launch", self.udid, BUNDLE, UNLOCK)
        time.sleep(wait)

    def shot(self, path):
        sh("xcrun", "simctl", "io", self.udid, "screenshot", path)

    def save_game(self, expect_placed=None):
        """The app's own save, which carries the puzzle and its solution.

        Read from the container plist directly. (`simctl spawn defaults
        export` looks like the fresher path but reads a different domain
        context and returns an empty dict — measured here.) When
        `expect_placed` is given, polls until the save shows at least that
        many mats, which absorbs cfprefsd's lazy flush after a commit.
        """
        container = sh("xcrun", "simctl", "get_app_container",
                       self.udid, BUNDLE, "data").stdout.strip()
        plist = os.path.join(container, f"Library/Preferences/{BUNDLE}.plist")
        for _ in range(16):
            try:
                with open(plist, "rb") as fh:
                    data = plistlib.load(fh)
                if "shikaku.saveGame.v1" in data:
                    save = json.loads(data["shikaku.saveGame.v1"])
                    if expect_placed is None or \
                            len(save["board"]["placed"]) >= expect_placed:
                        return save
            except (FileNotFoundError, KeyError, json.JSONDecodeError,
                    plistlib.InvalidFileException):
                pass
            time.sleep(0.5)
        return None


def flatten(path):
    """ASC rejects screenshots with an alpha channel."""
    from PIL import Image
    image = Image.open(path)
    if image.mode != "RGB":
        image.convert("RGB").save(path)


SCREEN_W = 414          # iPhone 11 Pro Max, points
BOARD_H_PADDING = 8     # Layout.s2 on each side of BoardView


class Board:
    """Maps grid cells to screen points.

    Horizontal geometry is fully determined by the layout constants: the
    board fills the padded width and cellSize is floored to a whole point,
    exactly as BoardGeometry computes it. Only the vertical origin needs the
    accessibility tree: any clue whose value is unique on the board anchors
    it. Solving both axes from AX frames (the first version) was fragile.
    """

    def __init__(self, sim):
        self.sim = sim
        self.ok = False
        save = sim.save_game()
        if save is None:
            return
        puzzle = save["puzzle"]
        self.size = puzzle["size"]
        self.clues = puzzle["clues"]
        self.solution = puzzle["solution"]

        # BoardGeometry: floored to the padded width, CAPPED at 64pt —
        # forgetting the cap put every drag on the wrong cells once.
        self.cell = min((SCREEN_W - 2 * BOARD_H_PADDING) // self.size, 64)
        board_len = self.cell * self.size
        self.ox = (SCREEN_W - board_len) / 2

        counts = {}
        for clue in self.clues:
            counts[clue["value"]] = counts.get(clue["value"], 0) + 1
        unique = {v for v, n in counts.items() if n == 1}
        oys = []
        screen = sim.clue_elements()
        for clue in self.clues:
            if clue["value"] not in unique:
                continue
            for value, point in screen:
                if value == clue["value"]:
                    oys.append(point[1] - (clue["cell"]["row"] + 0.5) * self.cell)
        if not oys:
            return
        oys.sort()
        self.oy = oys[len(oys) // 2]
        self.ok = True

    def center(self, row, col):
        return (self.ox + (col + 0.5) * self.cell,
                self.oy + (row + 0.5) * self.cell)

    def cell_of(self, point):
        return (int((point[1] - self.oy) // self.cell),
                int((point[0] - self.ox) // self.cell))

    def synced_placed(self):
        """The placed set, read back from the board itself: every AX clue
        element announcing ", housed" maps by position to exactly one clue,
        and every mat the driver lays is a single geometric fit, which is by
        definition that clue's solution rect. Resyncing every round instead
        of simulating means a missed or double-registered tap cannot drift
        the model (simulating drifted twice before this)."""
        housed = []
        for e in self.sim.tree():
            label = e.get("AXLabel") or ""
            if label.startswith("Clue ") and "housed" in label:
                f = e["frame"]
                housed.append(self.cell_of((f["x"] + f["width"] / 2,
                                            f["y"] + f["height"] / 2)))
        placed = []
        for i, clue in enumerate(self.clues):
            if (clue["cell"]["row"], clue["cell"]["col"]) in housed:
                placed.append(self.solution[i])
        return placed

    # -- Tap-only laying. idb's swipe silently drops on this simulator
    # (taps deliver, drags never commit — measured at three durations), so
    # the driver leans on the app's own remove-busywork move instead:
    # tapping a clue with exactly one geometric fit auto-places it. Gentle
    # boards are graded to need nothing beyond single-fit reasoning, so the
    # whole board is reachable this way; the fit check below replicates
    # the app's Candidates.rects + overlap filter.

    def fits(self, clue, placed):
        value, cell = clue["value"], clue["cell"]
        out = []
        for h in range(1, min(value, self.size) + 1):
            if value % h:
                continue
            w = value // h
            if w > self.size:
                continue
            for r0 in range(max(0, cell["row"] - h + 1),
                            min(cell["row"], self.size - h) + 1):
                for c0 in range(max(0, cell["col"] - w + 1),
                                min(cell["col"], self.size - w) + 1):
                    rect = {"minRow": r0, "minCol": c0,
                            "maxRow": r0 + h - 1, "maxCol": c0 + w - 1}
                    if any(o is not clue
                           and r0 <= o["cell"]["row"] <= rect["maxRow"]
                           and c0 <= o["cell"]["col"] <= rect["maxCol"]
                           for o in self.clues):
                        continue
                    if any(not (rect["maxRow"] < p["minRow"] or p["maxRow"] < r0
                                or rect["maxCol"] < p["minCol"] or p["maxCol"] < c0)
                           for p in placed):
                        continue
                    out.append(rect)
        return out

    def lay_by_tapping(self, stop_after=None):
        """Repeatedly taps whichever unplaced clue has exactly one fit,
        resyncing the placed set from the board's own accessibility state
        every round. Returns the number of mats when it stopped."""
        stalls = 0
        while True:
            if self.sim.find("Solved"):
                return len(self.clues)
            placed = self.synced_placed()
            if stop_after is not None and len(placed) >= stop_after:
                return len(placed)
            if len(placed) == len(self.clues):
                return len(placed)
            progressed = False
            for i, clue in enumerate(self.clues):
                if self.solution[i] in placed:
                    continue
                if len(self.fits(clue, placed)) != 1:
                    continue
                self.sim.tap(self.center(clue["cell"]["row"],
                                         clue["cell"]["col"]), wait=0.7)
                now = self.synced_placed()
                if len(now) > len(placed) or self.sim.find("Solved"):
                    progressed = True
                break
            if progressed:
                stalls = 0
                continue
            # One quiet round is allowed (a slow AX refresh); two is a stall.
            stalls += 1
            if stalls >= 2:
                return len(self.synced_placed())
            time.sleep(1.0)


def enter_game_with_readable_board(sim, attempts=6):
    """Play until a board appears that has a 1-clue (the safe first move that
    writes a save) and enough unique values to calibrate. Returns a Board."""
    for _ in range(attempts):
        play = sim.find("Lay out a room")
        if not play:
            back = sim.find("Back")
            if back:
                sim.tap(back, wait=1.5)
            continue
        sim.tap(play, wait=1.5)
        # The button now opens the size/difficulty sheet; its own primary
        # button carries the same label and starts the game.
        confirm = sim.find("Lay out a room")
        if confirm:
            sim.tap(confirm, wait=3.0)
        ones = [p for v, p in sim.clue_elements() if v == 1]
        if not ones:
            back = sim.find("Back")
            if back:
                sim.tap(back, wait=1.5)
            continue
        sim.tap(ones[0], wait=1.0)          # auto-places: writes the save
        board = Board(sim)
        if board.ok:
            return board
        back = sim.find("Back")
        if back:
            sim.tap(back, wait=1.5)
    return None


def solved_indices(board):
    """Solution rect indices in a stable order, 1-cell mats first (already
    placed ones are harmless to re-lay: redraw-over replaces in place)."""
    order = sorted(range(len(board.solution)),
                   key=lambda i: (board.solution[i]["minRow"],
                                  board.solution[i]["minCol"]))
    return order


def game_flow(sim, out_dir, appearance):
    """One pass through a live game: mid-solve shot, hint-argument shot, win
    shot. Returns the set of scene files written."""
    board = enter_game_with_readable_board(sim)
    if board is None:
        return False

    total = len(board.solution)
    target = max(2, int(total * 0.66))
    laid = board.lay_by_tapping(stop_after=target)
    if laid < target:
        print(f"  only {laid}/{target} mats laid — aborting scene",
              file=sys.stderr)
        return False
    time.sleep(0.8)
    sim.shot(os.path.join(out_dir, f"{appearance}-02-game.png"))

    # Climb the ladder to the drawn argument: nudge, technique, highlight.
    for label in ("Hint", "More of the hint", "More of the hint"):
        button = sim.find(label)
        if not button:
            break
        sim.tap(button, wait=1.4)
    time.sleep(0.8)
    sim.shot(os.path.join(out_dir, f"{appearance}-01-hint.png"))
    dismiss = sim.find("Dismiss hint")
    if dismiss:
        sim.tap(dismiss, wait=1.0)

    laid = board.lay_by_tapping()
    if laid < len(board.solution):
        print(f"  win scene stalled at {laid}/{len(board.solution)}",
              file=sys.stderr)
        return False
    time.sleep(1.6)                          # the stamp settles
    sim.shot(os.path.join(out_dir, f"{appearance}-06-win.png"))
    done = sim.find("Done")
    if done:
        sim.tap(done, wait=1.5)
    return True


def learn_flow(sim, out_dir, appearance):
    """The Prime Strips lesson (entered through its seal on Home) with its
    argument drawn, then today's room."""
    seal = sim.find("Prime Strips lesson")
    if not seal:
        return False
    sim.tap(seal, wait=1.5)
    # The seal now opens a three-door dialog; the lesson is the first door.
    lesson = sim.find("The lesson")
    if lesson:
        sim.tap(lesson, wait=2.0)
    show = sim.find("Show me")
    if not show:
        return False
    sim.tap(show, wait=2.2)                  # the argument draws itself
    sim.shot(os.path.join(out_dir, f"{appearance}-04-lesson.png"))
    back = sim.find("Back")
    if back:
        sim.tap(back, wait=1.5)

    card = sim.tree()
    target = None
    for el in card:
        label = el.get("AXLabel") or ""
        if label.startswith("Today needs") or label.startswith("Today's room"):
            f = el.get("frame") or {}
            target = (f.get("x", 0) + f.get("width", 0) / 2,
                      f.get("y", 0) + f.get("height", 0) / 2)
            break
    if not target:
        return True                          # lesson shot already succeeded
    sim.tap(target, wait=7.0)                # generation runs behind loading
    sim.shot(os.path.join(out_dir, f"{appearance}-05-daily.png"))
    back = sim.find("Back")
    if back:
        sim.tap(back, wait=1.5)
    return True


def main():
    out_dir = os.path.join(ROOT, "screenshots", "iphone-65")
    os.makedirs(out_dir, exist_ok=True)
    sim = Sim(UDID)

    for appearance in ("dark",):
        sim.appearance(appearance)
        sim.fresh_install()
        sim.launch()

        sim.shot(os.path.join(out_dir, f"{appearance}-03-home.png"))

        for flow in (game_flow, learn_flow):
            for attempt in range(3):
                if attempt:
                    sim.launch(wait=3.0)
                if flow(sim, out_dir, appearance):
                    break

        sim.launch(wait=2.0)

    from PIL import Image
    failures = 0
    for name in sorted(os.listdir(out_dir)):
        path = os.path.join(out_dir, name)
        flatten(path)
        size = Image.open(path).size
        good = size == EXPECTED
        failures += 0 if good else 1
        print(f"  {'OK ' if good else f'WRONG SIZE {size}'} {name}")
    expected_names = {f"{a}-{n:02d}-{s}.png"
                      for a in ("dark",)
                      for n, s in [(1, "hint"), (2, "game"), (3, "home"),
                                   (4, "lesson"), (5, "daily"), (6, "win")]}
    missing = expected_names - set(os.listdir(out_dir))
    for name in sorted(missing):
        print(f"  MISSING {name}", file=sys.stderr)
    sys.exit(1 if failures or missing else 0)


if __name__ == "__main__":
    main()
