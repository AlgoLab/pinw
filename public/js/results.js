var json = 'pintron-full-output.json';

//From: https://github.com/d3/d3-request/blob/master/README.md#json
d3.json(json, function (data) {
    var w = 900,
        h = 100;

    const seqId = data.genome.sequence_id;
    d3.select("#gene-coord")
        .html(seqId);

    //From: https://rest.ensembl.org/documentation/info/overlap_region
    const url = `https://rest.ensembl.org/overlap/region/human/${seqId}?feature=gene;content-type=application/json`;

    //Fetch the json from Ensembl and return the gene name
    //TODO include polyfill
    fetch(url)
        .then((resp) => resp.json()) //Transform the data into json
        .then(function (data) {
            var geneName = d3.select("#gene-name")
                .html(data[0].external_name);
        })
        .catch(function (err) {
            console.log(err.message);
        });

    //retrieve gene strand and populate the coordinates span
    var strand = d3.select("#gene-dir");
    var domain = seqId.split(/[:]/);
    if (data.genome.strand == "-") { //if the strand is reverse, initialize a descending xScale
        strand.html("Reverse");
        var xScale = d3.scaleLinear()
            .domain([+domain[2], +domain[1]])
            .range([130, w - 50]);
    } else { //else initialize an ascending one
        strand.html("Forward");
        var xScale = d3.scaleLinear()
            .domain([+domain[1], +domain[2]])
            .range([130, w - 50]);
    };

    //create an svg to draw the gene
    var geneVis = d3.select("#gene-vis")
        .append("svg")
        .attr("width", w)
        .attr("height", 100)
        .attr("class", "gene-box")
        .style("padding", "10px");

    //create an svg to draw the isoforms
    var isoVis = d3.select("#iso-vis")
        .append("svg")
        .attr("width", w)
        .attr("height", h)
        .attr("id", "t")
        .attr("class", "iso-box")
        .style("padding", "10px");

    //draw the axis on the xScale
    var axis = d3.axisBottom(xScale)
        .ticks(5);

    //append the axis to the isoforms SVG
    isoVis.append("g")
        .call(axis);

    //start drawing the full-length gene
    var geneGroup = geneVis.append("g")
        .attr("id", "gene")
        .attr("y", 50);

    //append the axis to the gene view
    var gX = geneVis.append("g")
        .attr("class", "axis axis--x")
        .call(axis);

    //variables to hold the introns and isoforms data as arrays
    var intronData = Object.values(data.introns);
    var isoData = Object.values(data.isoforms);

    //create the exons array
    var exonsArray = [];
    for (i = 1; i < data.number_isoforms + 1; i++) {
        for (k = 0; k < data.isoforms[i].exons.length; k++) {
            exonsArray.push(data.isoforms[i].exons[k]);
            data.isoforms[i].exons[k].count = 0;
        }
    };

    //sort the array
    exonsArray.sort(function (a, b) {
        return a["relative start"] - b["relative start"] || b["relative end"] - a["relative end"];
    });

    //count every exon occurrence
    function countDup(exonsArray) {
        const start = x => exonsArray[x]["relative start"];
        const end = x => exonsArray[x]["relative end"];
        let hash = new Map();
        for (var i = 0; i < exonsArray.length; i++) {
            let key = start(i) + ':' + end(i);
            let item = exonsArray[i];
            let values = hash.get(key);
            if (values) values.push(item);
            else hash.set(key, [item]);
        }
        let ar = [];
        hash.forEach((v, k, m) => (count = 1, v.forEach(i => i.count += count++), ar.push(v[v.length - 1])));
        return ar;
    }
    exonsArray = countDup(exonsArray);

    //calculate percentage of occurrence
    function calcPerc(count) {
        return (count / data.number_isoforms) * 100
    };

    //draw the gene introns
    var geneIntrons = geneGroup.append("g")
        .selectAll("line")
        .data(intronData)
        .enter().append("line")
        .attr("x1", function (d) { return xScale(d["chromosome start"]) })
        .attr("x2", function (d) { return xScale(d["chromosome end"]) })
        .attr("y1", 50)
        .attr("y2", 50)
        .attr("stroke", "black")
        .attr("stroke-width", 5);

    //draw the gene exons
    var geneExons = geneGroup.append("g")
        .selectAll("line")
        .data(exonsArray)
        .enter().append("line")
        .attr("x1", function (d) { return xScale(d["chromosome start"]) })
        .attr("x2", function (d) { return xScale(d["chromosome end"]) })
        .attr("y1", 50)
        .attr("y2", 50)
        .attr("stroke-width", 35).each(function (d) {
            var ex = d3.select(this);
            var perc = calcPerc(d.count);
            //conditionally color the exon based on percentage
            if (perc < 25) {
                ex.attr("stroke", "#00cd00");
            } else if (perc > 24 && perc < 50) {
                ex.attr("stroke", "#00b300")
            } else if (perc > 49 && perc < 75) {
                ex.attr("stroke", "#009a00")
            } else if (perc > 74 && perc < 90) {
                ex.attr("stroke", "#008000")
            } else if (perc > 89 && perc < 100) {
                ex.attr("stroke", "#006700")
            } else if (perc === 100) {
                ex.attr("stroke", "#004d00")
            };
        });

    //add a y value to each isoform
    var yVal = 50;
    isoData.forEach(function (element) {
        element["y"] = yVal;
        element.exons.forEach(function (elem) {
            elem["y"] = yVal;
        })
        yVal += 50;
    });

    //draw the isoforms
    var isoform = isoVis.append("g")
        .selectAll("g")
        .data(isoData)
        .enter().append("g")
        .attr("class", "isoform")
        .attr("y", function (d) { return (d.y); })
        .each(function (d) {
            isoVis.attr("height", (d.y + 50));
            var g = d3.select(this);

            //create RefSeq label
            g.append("text")
                .text(function (d) { return d.RefSeq })
                .attr("y", function (d) { return (d.y); });

            //create exons group
            var exons = g.append("g")
                .attr("class", "exons")
                .selectAll("line")
                .data(function (d) { return d.exons; })
                .enter().append("line")
                .attr("stroke", "green")
                .attr("stroke-width", 35).each(function (d) {
                    var gLine = d3.select(this);
                    gLine.attr("x1", function (d) { return xScale(d["chromosome start"]); })
                        .attr("x2", function (d) { return xScale(d["chromosome end"]); })
                        .attr("y1", function (d) { return (d.y); })
                        .attr("y2", function (d) { return (d.y); })
                        .attr("data-toggle", "popover")
                        .attr("data-content", "<b>3utr length:</b> " + d["3utr length"]
                        + "<br><b>5utr length:</b> " + d["5utr length"]
                        + "<br><b>Chr start:</b> " + d["chromosome start"]
                        + "<br><b>Chr end:</b> " + d["chromosome end"]);
                });
            //create introns group
            g.append("g")
                .attr("class", "introns")
                .attr("y", function (d) { return d.y; })
                .selectAll("line")
                .data(function (d) { return d.introns; })
                .enter().append("line")
                .attr("stroke", "black")
                .attr("stroke-width", 5).each(function (d) {
                    var bLine = d3.select(this);
                    yPos = this.parentNode.getAttribute("y");
                    bLine.attr("x1", function (d) { return xScale(intronData[d - 1]["chromosome start"]); })
                        .attr("x2", function (d) { return xScale(intronData[d - 1]["chromosome end"]); })
                        .attr("y1", function (d) { return (yPos); })
                        .attr("y2", function (d) { return (yPos); })
                        .attr("data-toggle", "popover")
                        .attr("data-content", "<b>BPS position: </b> " + intronData[d - 1]["BPS score"]
                        + "<br><b>BPS score:</b> " + intronData[d - 1]["BPS score"]
                        + "<br><b>Chr start:</b> " + intronData[d - 1]["chromosome start"]
                        + "<br><b>Chr end:</b> " + intronData[d - 1]["chromosome end"]
                        + "<br><b>Length:</b> " + intronData[d - 1].length
                        + "<br><b>Pattern:</b> " + intronData[d - 1].pattern
                        + "<br><b>Prefix:</b> " + intronData[d - 1].prefix
                        + "<br><b>Suffix:</b> " + intronData[d - 1].suffix);
                });
            //drag handler
            g.append("text")
                .text("|||")
                .style("fill", "black")
                .style("writing-mode", "tb")
                .style("glyph-orientation-vertical", 0)
                .style("cursor", "move")
                .style("font-size", "25px")
                .attr("class", "handler")
                .attr("x", w - 60)
                .attr("y", function (d) { return (d.y - 10); });
        });

    //zoom function
    var zoom = d3.zoom()
        .scaleExtent([1, 40])
        .translateExtent([[-100, -100], [w + 90, h + 100]])
        .on("zoom", zoomed);

    geneVis.call(zoom);

    function zoomed() {
        // re-scale x axis during zoom; 
        gX.transition()
            .duration(50)
            .call(axis.scale(d3.event.transform.rescaleX(xScale)));

        // re-draw lines using new x-axis scale; 
        var newScale = d3.event.transform.rescaleX(xScale);
        geneExons.attr("x1", function (d) { return newScale(d["chromosome start"]); });
        geneExons.attr("x2", function (d) { return newScale(d["chromosome end"]); });
        geneIntrons.attr("x1", function (d) { return newScale(d["chromosome start"]); });
        geneIntrons.attr("x2", function (d) { return newScale(d["chromosome end"]); });
    };

    //reset button
    var btn = geneVis.append("g")
        .attr("y", 1);

    btn.append("rect")
        .attr("width", 40)
        .attr("height", 20)
        .style("fill", "#ededed")
        .style("cursor", "pointer")
        .style("stroke", "#cccccc")
        .style("stroke-width", 1)
        .on('click', resetted);

    btn.append("text")
        .attr("y", 13)
        .attr("x", 20)
        .text("Reset")
        .attr("text-anchor", "middle")
        .style("fill", "black")
        .style("font-size", "11px")
        .style("pointer-events", "none");

    //reset function
    function resetted() {
        geneVis.transition()
            .duration(750)
            .call(zoom.transform, d3.zoomIdentity);
    };


    //drag and drop
    d3.selectAll(".isoform").call(d3.drag()
        .subject(function (d) {
            return { y: d3.event.y };
        })
        .on("start", function (d) {
            trigger = d3.event.sourceEvent.target.className.baseVal;

            if (trigger == "handler") {
                // Move the row that is moving on the front
                sel = d3.select(this);
                sel.moveToFront();
            }
        })
        .on("drag", function (d) {
            if (trigger == "handler") {
                var curY = d3.event.y - this.getAttribute("y");
                d3.select(this).attr("transform", function (d) {
                    return "translate(0," + curY + ")";
                });
            }
        })
    );

    d3.selection.prototype.moveToFront = function () {
        return this.each(function () {
            this.parentNode.appendChild(this);
        });
    };

});  