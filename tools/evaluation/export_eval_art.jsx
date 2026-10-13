// Run from Illustrator with the VOLT26 document open:
//   File > Scripts > Other Script...  and pick this file.
//
// Exports the stage evaluation's WANTED artboard as Illustrator itself renders
// it (images, gradients, blend modes and effects included, which the SVG
// export loses), into tools/evaluation/art/:
//
//   backdrop.png   1920x1080, the artboard without what the screen draws
//                  itself: every text but "WANTED", the player plates, the
//                  judgment ladder, the graph frame, the song picture and the
//                  red overlay on its window.
//   full.png       1920x1080, the whole artboard (for comparison).
//   items.json     every top-level item touching the artboard: type, name,
//                  bounds in artboard pixels, blend mode, opacity, and whether
//                  it went into backdrop.png.
//
// The open document is left alone: items are duplicated into a scratch
// document that is closed without saving.
#target illustrator
(function () {
	var here = File($.fileName).parent;
	var out = Folder(here + "/art");
	if (!out.exists) out.create();

	var source = app.activeDocument;
	app.coordinateSystem = CoordinateSystem.DOCUMENTCOORDINATESYSTEM;

	// The evaluation artboard is 87.2 px right of and 2804 px below the first
	// artboard (as in the SVG export, whose origin is the first artboard).
	var first = source.artboards[0].artboardRect;
	var board = null, boards = [];
	for (var a = 0; a < source.artboards.length; a++) {
		var r = source.artboards[a].artboardRect;
		boards.push("[" + (r[0] - first[0]) + "," + (first[1] - r[1]) + "," + (r[2] - r[0]) + "," + (r[1] - r[3]) + "]");
		if (Math.abs(r[0] - first[0] - 87.2) < 4 && Math.abs(first[1] - r[1] - 2804) < 4) board = r;
	}
	if (!board) {
		alert("Evaluation artboard not found.\nArtboards (x, y, w, h from the first):\n" + boards.join("\n"));
		return;
	}
	var W = board[2] - board[0], H = board[1] - board[3];

	function rel(b) { return [b[0] - board[0], board[1] - b[1], b[2] - board[0], board[1] - b[3]]; }
	function near(b, x0, y0, x1, y1) {
		var t = 14;
		return Math.abs(b[0] - x0) < t && Math.abs(b[1] - y0) < t && Math.abs(b[2] - x1) < t && Math.abs(b[3] - y1) < t;
	}
	// What the screen draws itself, by its bounds in artboard pixels.
	var DRAWN = [
		["plates", 23, -4, 796, 377],
		["ladder", 73, 372, 807, 966],
		["graph", 11, 933, 773, 1121],
		["window", 490.6, 109.6, 1802.8, 970.4],
	];
	function trim(s) { return String(s).replace(/^\s+|\s+$/g, ""); }

	var items = [];
	for (var i = source.pageItems.length - 1; i >= 0; i--) {   // back to front
		var it = source.pageItems[i];
		if (it.parent.typename != "Layer") continue;
		if (it.hidden || it.layer.visible == false) continue;
		var b;
		try { b = rel(it.visibleBounds); } catch (e) { continue; }
		if (b[2] < 0 || b[0] > W || b[3] < 0 || b[1] > H) continue;
		var reason = "";
		if (it.typename == "TextFrame" && trim(it.contents) != "WANTED") reason = "text";
		for (var d = 0; d < DRAWN.length && !reason; d++) {
			if (near(b, DRAWN[d][1], DRAWN[d][2], DRAWN[d][3], DRAWN[d][4])) reason = DRAWN[d][0];
		}
		items.push({ item: it, bounds: b, reason: reason });
	}

	function q(s) { return '"' + String(s).replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/[\r\n]/g, " ") + '"'; }
	function num(n) { return Math.round(n * 10) / 10; }
	var lines = [];
	for (var k = 0; k < items.length; k++) {
		var e = items[k], mode = "", opacity = 100;
		try { mode = String(e.item.blendingMode); } catch (x) {}
		try { opacity = e.item.opacity; } catch (x) {}
		lines.push("{" + q("type") + ":" + q(e.item.typename) + "," + q("name") + ":" + q(e.item.name || "") +
			"," + q("bounds") + ":[" + num(e.bounds[0]) + "," + num(e.bounds[1]) + "," + num(e.bounds[2]) + "," + num(e.bounds[3]) + "]" +
			"," + q("blend") + ":" + q(mode) + "," + q("opacity") + ":" + num(opacity) +
			"," + q("drawnByScreen") + ":" + q(e.reason) + "}");
	}
	var json = File(out + "/items.json");
	json.encoding = "UTF-8";
	json.open("w");
	json.write("{" + q("artboards") + ":[" + boards.join(",") + "]," + q("items") + ":[\n" + lines.join(",\n") + "\n]}\n");
	json.close();

	function exportPng(name, keep) {
		var doc = app.documents.add(DocumentColorSpace.RGB, W, H);
		app.coordinateSystem = CoordinateSystem.DOCUMENTCOORDINATESYSTEM;
		doc.artboards[0].artboardRect = board;
		var target = doc.layers[0];
		for (var n = 0; n < items.length; n++) {
			if (keep(items[n])) items[n].item.duplicate(target, ElementPlacement.PLACEATBEGINNING);
		}
		var options = new ExportOptionsPNG24();
		options.artBoardClipping = true;
		options.antiAliasing = true;
		options.transparency = false;
		options.horizontalScale = 100 * 1920 / W;
		options.verticalScale = 100 * 1080 / H;
		doc.exportFile(File(out + "/" + name), ExportType.PNG24, options);
		doc.close(SaveOptions.DONOTSAVECHANGES);
	}

	exportPng("backdrop.png", function (e) { return e.reason == ""; });
	exportPng("full.png", function (e) { return true; });
	app.activeDocument = source;
	alert("Evaluation art exported to\n" + out.fsName);
})();
