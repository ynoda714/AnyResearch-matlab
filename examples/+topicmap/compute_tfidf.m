function tfidfMatrix = compute_tfidf(countMatrix)
%COMPUTE_TFIDF Compute a simple TF-IDF matrix from term counts.

if isempty(countMatrix)
    tfidfMatrix = countMatrix;
    return;
end

rowSums = sum(countMatrix, 2);
rowSums(rowSums == 0) = 1;
tf = countMatrix ./ rowSums;

docFreq = sum(countMatrix > 0, 1);
nDocs = size(countMatrix, 1);
idf = log((nDocs + 1) ./ (docFreq + 1)) + 1;

tfidfMatrix = tf .* idf;
end
