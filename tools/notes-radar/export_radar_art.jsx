// Run from Illustrator: File > Scripts > Other Script...
// Leaves the active document alone: every top-level item is duplicated into a
// scratch document, which is dumped (art/structure.json: names, types, bounds,
// path anchors), exported (art/radar_export.svg) and closed without saving.
// Exporting the open document directly would rebind it to the SVG file.
#target illustrator
(function () {
	var here = File($.fileName).parent;
	var out = Folder(here + "/art");
	if (!out.exists) out.create();
	var source = app.activeDocument;
	var doc = app.documents.add(DocumentColorSpace.RGB, 1920, 1080);
	var target = doc.layers[0];
	for (var s = source.pageItems.length - 1; s >= 0; s--) {
		var src = source.pageItems[s];
		if (src.parent.typename != "Layer") continue;
		if (src.hidden || src.layer.visible == false) continue;
		src.duplicate(target, ElementPlacement.PLACEATBEGINNING);
	}

	function q(s) { return '"' + String(s).replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/[\r\n]/g, " ") + '"'; }
	function num(n) { return Math.round(n * 100) / 100; }
	function arr(a) { var r = []; for (var i = 0; i < a.length; i++) r.push(num(a[i])); return "[" + r.join(",") + "]"; }

	function dumpItem(it, depth) {
		var s = "{" + q("type") + ":" + q(it.typename) + "," + q("name") + ":" + q(it.name || "") +
			"," + q("hidden") + ":" + (it.hidden ? "true" : "false");
		try { s += "," + q("bounds") + ":" + arr(it.geometricBounds); } catch (e) {}
		if (it.typename == "PathItem") {
			var pts = [];
			for (var i = 0; i < it.pathPoints.length; i++) pts.push(arr(it.pathPoints[i].anchor));
			s += "," + q("closed") + ":" + (it.closed ? "true" : "false") + "," + q("points") + ":[" + pts.join(",") + "]";
			try { if (it.filled && it.fillColor.typename == "RGBColor") s += "," + q("fill") + ":" + arr([it.fillColor.red, it.fillColor.green, it.fillColor.blue]); } catch (e) {}
		}
		if (it.typename == "TextFrame") { try { s += "," + q("text") + ":" + q(it.contents); } catch (e) {} }
		if (depth < 8) {
			var kids = [];
			try { for (var k = 0; k < it.pageItems.length; k++) kids.push(dumpItem(it.pageItems[k], depth + 1)); } catch (e) {}
			try { if (it.typename == "CompoundPathItem") for (var p = 0; p < it.pathItems.length; p++) kids.push(dumpItem(it.pathItems[p], depth + 1)); } catch (e) {}
			if (kids.length) s += "," + q("items") + ":[" + kids.join(",") + "]";
		}
		return s + "}";
	}
	function dumpLayer(l) {
		var s = "{" + q("layer") + ":" + q(l.name) + "," + q("visible") + ":" + (l.visible ? "true" : "false");
		var kids = [];
		for (var i = 0; i < l.pageItems.length; i++) {
			var it = l.pageItems[i];
			if (it.parent == l) kids.push(dumpItem(it, 0));
		}
		var subs = [];
		for (var j = 0; j < l.layers.length; j++) subs.push(dumpLayer(l.layers[j]));
		return s + "," + q("items") + ":[" + kids.join(",") + "]," + q("layers") + ":[" + subs.join(",") + "]}";
	}

	var abs = [];
	for (var a = 0; a < doc.artboards.length; a++)
		abs.push("{" + q("name") + ":" + q(doc.artboards[a].name) + "," + q("rect") + ":" + arr(doc.artboards[a].artboardRect) + "}");
	var layers = [];
	for (var L = 0; L < doc.layers.length; L++) layers.push(dumpLayer(doc.layers[L]));
	var json = "{" + q("document") + ":" + q(doc.name) + "," + q("active") + ":" + doc.artboards.getActiveArtboardIndex() +
		"," + q("artboards") + ":[" + abs.join(",") + "]," + q("layers") + ":[" + layers.join(",") + "]}";
	var f = File(out + "/structure.json");
	f.encoding = "UTF-8"; f.open("w"); f.write(json); f.close();

	var opt = new ExportOptionsSVG();
	opt.fontType = SVGFontType.OUTLINEFONT;
	opt.embedRasterImages = true;
	opt.coordinatePrecision = 3;
	opt.cssProperties = SVGCSSPropertyLocation.PRESENTATIONATTRIBUTES;
	opt.saveMultipleArtboards = false;
	doc.exportFile(File(out + "/radar_export.svg"), ExportType.SVG, opt);
	doc.close(SaveOptions.DONOTSAVECHANGES);
	source.activate();
	alert("VOLT26: export done in " + decodeURI(out.fsName));
})();
