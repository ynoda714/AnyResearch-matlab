function [embeddings, meta] = embed_documents(texts, opts)
%EMBED_DOCUMENTS Embed documents with BERT-Base and return 768-D vectors.

arguments
    texts (:,1) string
    opts.batchSize (1,1) double {mustBePositive, mustBeInteger} = 64
    opts.maxChars (1,1) double {mustBePositive, mustBeInteger} = 1000
    opts.useGpu (1,1) logical = local_default_use_gpu()
    opts.progressEvery (1,1) double {mustBePositive, mustBeInteger} = 10
end

if exist("bert", "file") ~= 2
    error("topicmap:embed_documents:MissingBertFunction", ...
        "bert() is not available. Install Text Analytics Toolbox and Deep Learning Toolbox.");
end

texts = local_prepare_texts(texts, opts.maxChars);
nDocs = numel(texts);

if nDocs == 0
    embeddings = zeros(0, 768);
    meta = local_meta(opts, false, 0, 0);
    return;
end

[net, tokenizer] = local_load_bert_base();
useGpu = local_resolve_gpu_option(opts.useGpu);
nBatches = ceil(nDocs / opts.batchSize);
embeddings = zeros(nDocs, 768, "single");
wallStart = tic;

for batchIdx = 1:nBatches
    firstRow = (batchIdx - 1) * opts.batchSize + 1;
    lastRow = min(batchIdx * opts.batchSize, nDocs);
    batchTexts = texts(firstRow:lastRow);

    [tokenCodes, segments] = encode(tokenizer, batchTexts);
    [inputIds, attentionMask, segIds] = local_pack_batch(tokenCodes, segments, tokenizer);

    if useGpu
        inputIds = gpuArray(inputIds);
        attentionMask = gpuArray(attentionMask);
        segIds = gpuArray(segIds);
    end

    hidden = predict(net, inputIds, attentionMask, segIds, ...
        InputDataFormats=["CTB", "CTB", "CTB"]);
    hidden = local_collect_hidden(hidden);
    batchEmbeddings = squeeze(hidden(:, 1, :))';
    if isvector(batchEmbeddings)
        batchEmbeddings = reshape(batchEmbeddings, 1, []);
    end
    embeddings(firstRow:lastRow, :) = single(batchEmbeddings);

    if batchIdx == 1 || batchIdx == nBatches || mod(batchIdx, opts.progressEvery) == 0
        elapsed = toc(wallStart);
        docsDone = lastRow;
        docsPerSecond = docsDone / max(elapsed, eps);
        fprintf("[topicmap] BERT batch %d/%d  docs=%d/%d  rate=%.1f docs/s\n", ...
            batchIdx, nBatches, docsDone, nDocs, docsPerSecond);
    end
end

meta = local_meta(opts, useGpu, nDocs, toc(wallStart));
end

function tf = local_default_use_gpu()
tf = exist("canUseGPU", "file") == 2 && canUseGPU();
end

function useGpu = local_resolve_gpu_option(requested)
if ~requested
    useGpu = false;
    return;
end

if exist("canUseGPU", "file") ~= 2 || ~canUseGPU()
    error("topicmap:embed_documents:GpuUnavailable", ...
        "useGpu=true was requested, but no supported GPU is available.");
end
useGpu = true;
end

function texts = local_prepare_texts(texts, maxChars)
texts = topicmap.clean_text(string(texts));
texts(ismissing(texts)) = "";
texts(strlength(texts) == 0) = "untitled document";

for i = 1:numel(texts)
    if strlength(texts(i)) > maxChars
        texts(i) = extractBetween(texts(i), 1, maxChars);
    end
end
end

function [net, tokenizer] = local_load_bert_base()
try
    [net, tokenizer] = bert(Model="base");
catch ex
    if contains(ex.message, "support package", IgnoreCase=true) || ...
            contains(ex.message, "Add-On Explorer", IgnoreCase=true)
        error("topicmap:embed_documents:MissingBertBaseSupport", ...
            ["BERT-Base support is not installed. Install " ...
             "'Text Analytics Toolbox Model for BERT-Base Network' from Add-On Explorer, " ...
             "then rerun the pipeline. Original error: %s"], ex.message);
    end
    error("topicmap:embed_documents:BertLoadFailed", ...
        "Failed to load BERT-Base: %s", ex.message);
end
end

function [inputIds, attentionMask, segIds] = local_pack_batch(tokenCodes, segments, tokenizer)
nDocs = numel(tokenCodes);
lengths = cellfun(@numel, tokenCodes);
maxLen = max(lengths);

paddingCode = single(tokenizer.PaddingCode);
inputIds = repmat(reshape(paddingCode, 1, 1, 1), 1, maxLen, nDocs);
attentionMask = zeros(1, maxLen, nDocs, "single");
segIds = ones(1, maxLen, nDocs, "single");

for i = 1:nDocs
    len = lengths(i);
    inputIds(1, 1:len, i) = single(tokenCodes{i});
    attentionMask(1, 1:len, i) = 1;
    segIds(1, 1:len, i) = single(segments{i});
end
end

function meta = local_meta(opts, useGpu, nDocs, elapsedSeconds)
meta = struct();
meta.model = "bert-base";
meta.batchSize = opts.batchSize;
meta.maxChars = opts.maxChars;
meta.useGpu = useGpu;
meta.nDocs = nDocs;
meta.elapsedSeconds = elapsedSeconds;
end

function hidden = local_collect_hidden(hidden)
if isa(hidden, "dlarray")
    hidden = extractdata(hidden);
end
hidden = gather(hidden);
end
