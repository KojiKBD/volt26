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

	var rows = [];
	for (var n = 0; n < items.length; n++) {
		var it = items[n];
		var id = (n < 10 ? "0" : "") + n;
		var doc = scratch();
		it.duplicate(doc.layers[0], ElementPlacement.PLACEATBEGINNING);
		exportPng(doc, "item_" + id + ".png");
		doc.close(SaveOptions.DONOTSAVECHANGES);
		var b = it.visibleBounds;
		var text = "";
		if (it.typename == "TextFrame") { try { text = it.contents; } catch (e) {} }
		rows.push("{" + q("id") + ":" + q(id) + "," + q("type") + ":" + q(it.typename) + "," + q("name") + ":" + q(it.name || "") +
			"," + q("text") + ":" + q(text) + "," + q("opacity") + ":" + num(it.opacity) +
			"," + q("bounds") + ":[" + num(b[0] - abRect[0]) + "," + num(abRect[1] - b[1]) + "," + num(b[2] - abRect[0]) + "," + num(abRect[1] - b[3]) + "]}");
	}

	var all = scratch();
	for (var c = 0; c < items.length; c++) items[c].duplicate(all.layers[0], ElementPlacement.PLACEATBEGINNING);
	exportPng(all, "composite.png");
	all.close(SaveOptions.DONOTSAVECHANGES);

	var f = new File(out + "/items.json");
	f.encoding = "UTF-8";
	f.open("w");
	f.write("[\n" + rows.join(",\n") + "\n]\n");
	f.close();
	alert("Song select art: " + items.length + " items exported to " + out.fsName);
})();
