// Second pass of export_song_select_art.jsx; run it after that one.
// Run from Illustrator: File > Scripts > Other Script... (Ctrl+F12)
//
// Exports the song selection mockup piece by piece.  The active document is
// left alone: each top-level item that touches the active artboard is
// duplicated into a scratch 1920x1080 document, exported as a transparent PNG
// clipped to the artboard (art/item_NN.png) and the scratch document is
// closed without saving.  art/items.json lists every exported item with its
// type, name and bounds (artboard pixels, y down); art/composite.png is the
// whole artboard.  tools/song-select/build_song_select_art.py crops and names
// the pieces for the theme.
#target illustrator
(function () {
	var here = File($.fileName).parent;
	var out = Folder(here + "/art");
	if (!out.exists) out.create();
	var source = app.activeDocument;
	var abIndex = source.artboards.getActiveArtboardIndex();
	var abRect = source.artboards[abIndex].artboardRect; // left, top, right, bottom
	var abW = abRect[2] - abRect[0], abH = abRect[1] - abRect[3];

	function q(s) { return '"' + String(s).replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/[\r\n]/g, " ") + '"'; }
	function num(n) { return Math.round(n * 100) / 100; }

	function touchesArtboard(it) {
		var b = it.visibleBounds;
		return !(b[2] < abRect[0] || b[0] > abRect[2] || b[1] < abRect[3] || b[3] > abRect[1]);
	}

	function scratch() {
		var doc = app.documents.add(DocumentColorSpace.RGB, abW, abH);
		doc.artboards[0].artboardRect = abRect;
		return doc;
	}

	function exportPng(doc, name) {
		var opts = new ExportOptionsPNG24();
		opts.transparency = true;
		opts.antiAliasing = true;
		opts.artBoardClipping = true;
		opts.horizontalScale = 100;
		opts.verticalScale = 100;
		doc.exportFile(new File(out + "/" + name), ExportType.PNG24, opts);
	}

	// Top-level items of every visible layer, back to front.
	var items = [];
	for (var L = source.layers.length - 1; L >= 0; L--) {
		var layer = source.layers[L];
		if (!layer.visible) continue;
		for (var i = layer.pageItems.length - 1; i >= 0; i--) {
			var it = layer.pageItems[i];
			if (it.parent != layer || it.hidden) continue;
			if (touchesArtboard(it)) items.push(it);
		}
	}

	// Second pass: the children of the groups the theme takes apart (the
	// SELECT logo, a plain and the highlighted song row, the info panel), one
	// level down, as art/part_<group>_<child>.png with art/parts.json.
	var wanted = [14, 15, 22, 34];
	var rows = [];
	function dumpKids(group, gid, depth) {
		for (var k = group.pageItems.length - 1; k >= 0; k--) {
			var kid = group.pageItems[k];
			if (kid.parent != group || kid.hidden) continue;
			var kidId = gid + "_" + (k < 10 ? "0" : "") + k;
			var doc = scratch();
			kid.duplicate(doc.layers[0], ElementPlacement.PLACEATBEGINNING);
			exportPng(doc, "part_" + kidId + ".png");
			doc.close(SaveOptions.DONOTSAVECHANGES);
			var b = kid.visibleBounds;
			var text = "";
			if (kid.typename == "TextFrame") { try { text = kid.contents; } catch (e) {} }
			var font = "", size = 0;
			if (kid.typename == "TextFrame") { try { font = kid.textRange.characterAttributes.textFont.name; size = kid.textRange.characterAttributes.size; } catch (e) {} }
			rows.push("{" + q("id") + ":" + q(kidId) + "," + q("type") + ":" + q(kid.typename) +
				"," + q("text") + ":" + q(text) + "," + q("font") + ":" + q(font) + "," + q("size") + ":" + num(size) +
				"," + q("opacity") + ":" + num(kid.opacity) + "," + q("blend") + ":" + q(String(kid.blendingMode)) +
				"," + q("bounds") + ":[" + num(b[0] - abRect[0]) + "," + num(abRect[1] - b[1]) + "," + num(b[2] - abRect[0]) + "," + num(abRect[1] - b[3]) + "]}");
			if (depth < 1 && kid.typename == "GroupItem") dumpKids(kid, kidId, depth + 1);
		}
	}
	for (var w = 0; w < wanted.length; w++) {
		var g = items[wanted[w]];
		if (g && g.typename == "GroupItem") dumpKids(g, (wanted[w] < 10 ? "0" : "") + wanted[w], 0);
	}
	var f = new File(out + "/parts.json");
	f.encoding = "UTF-8";
	f.open("w");
	f.write("[\n" + rows.join(",\n") + "\n]\n");
	f.close();
	alert("Song select parts: " + rows.length + " exported to " + out.fsName);
})();
