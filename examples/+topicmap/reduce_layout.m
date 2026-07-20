function coordinates = reduce_layout(featureMatrix, methodName, nDims, opts)
%REDUCE_LAYOUT Reduce features into a requested number of dimensions.

arguments
    featureMatrix double
    methodName (1,1) string = "umap"
    nDims (1,1) double {mustBePositive, mustBeInteger} = 2
    opts.seed (1,1) double = 0
end

nRows = size(featureMatrix, 1);
if isempty(featureMatrix)
    coordinates = zeros(nRows, nDims);
    return;
end
if nRows == 1
    coordinates = zeros(1, nDims);
    return;
end

X = double(featureMatrix);

switch lower(methodName)
    case "pca"
        coordinates = local_pca_reduce(X, nDims);
    case "tsne"
        coordinates = tsne(X, NumDimensions=nDims, Standardize=true);
    case "umap"
        if exist("umap", "file") ~= 2
            error("topicmap:reduce_layout:MissingUmap", ...
                "umap() is not available. Use MATLAB R2026a or later.");
        end
        rng(opts.seed, "twister");
        coordinates = umap(X, NumDimensions=nDims);
    otherwise
        error("topicmap:reduce_layout:UnknownMethod", ...
            "Unknown layout method: %s", methodName);
end
end

function coordinates = local_pca_reduce(X, nDims)
X = X(:, any(X ~= 0, 1));
if isempty(X)
    coordinates = zeros(size(X, 1), nDims);
    return;
end
if size(X, 2) == 1
    centered = X(:, 1) - mean(X(:, 1), 1);
    coordinates = zeros(size(X, 1), nDims);
    coordinates(:, 1) = centered;
    return;
end

[~, score] = pca(X);
coordinates = zeros(size(X, 1), nDims);
keepDims = min(size(score, 2), nDims);
coordinates(:, 1:keepDims) = score(:, 1:keepDims);
end
