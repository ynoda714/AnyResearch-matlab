function outputPath = plot_topic_map(coordinates, clusterIds, outputPath, opts)
%PLOT_TOPIC_MAP Plot a 2-D topic map colored by cluster id.

arguments
    coordinates double
    clusterIds (:,1) double
    outputPath (1,1) string
    opts.titleText (1,1) string = "Topic Map"
    opts.markerSize (1,1) double {mustBePositive} = 8
    opts.faceAlpha (1,1) double {mustBeGreaterThanOrEqual(opts.faceAlpha,0), mustBeLessThanOrEqual(opts.faceAlpha,1)} = 0.35
    opts.edgeAlpha (1,1) double {mustBeGreaterThanOrEqual(opts.edgeAlpha,0), mustBeLessThanOrEqual(opts.edgeAlpha,1)} = 0.15
end

if size(coordinates, 2) ~= 2
    error("topicmap:plot_topic_map:Expected2D", ...
        "coordinates must be an N-by-2 matrix.");
end
if size(coordinates, 1) ~= numel(clusterIds)
    error("topicmap:plot_topic_map:SizeMismatch", ...
        "coordinates and clusterIds must have matching row counts.");
end

clusterIds = clusterIds(:);
uniqueClusters = unique(clusterIds, "sorted");
colors = lines(max(numel(uniqueClusters), 1));

fig = figure("Visible", "off", "Color", "w");
cleanup = onCleanup(@() close(fig));
ax = axes(fig);
hold(ax, "on");

for i = 1:numel(uniqueClusters)
    clusterId = uniqueClusters(i);
    mask = clusterIds == clusterId;
    scatter(ax, coordinates(mask, 1), coordinates(mask, 2), opts.markerSize, ...
        colors(i, :), "filled", ...
        MarkerFaceAlpha=opts.faceAlpha, MarkerEdgeAlpha=opts.edgeAlpha, ...
        DisplayName=sprintf("Cluster %d", clusterId));
end

hold(ax, "off");
grid(ax, "on");
title(ax, opts.titleText);
xlabel(ax, "UMAP-1");
ylabel(ax, "UMAP-2");
legend(ax, "Location", "eastoutside");

outDir = fileparts(char(outputPath));
if strlength(string(outDir)) > 0 && ~isfolder(outDir)
    mkdir(outDir);
end

exportgraphics(ax, outputPath, Resolution=200);
end
