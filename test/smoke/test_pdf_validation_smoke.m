function test_pdf_validation_smoke()
% test_pdf_validation_smoke - M12: PDF quality validation smoke test
%   Test cases:
%     Case1: Valid PDF (%PDF- header, >1KB) -> valid
%     Case2: 0-byte file -> failed_auto_0kb
%     Case3: 500-byte file (<1KB) -> failed_auto_0kb
%     Case4: 2KB but no PDF header -> failed_auto_corrupt
%     Case5: File not found -> failed_auto_corrupt

tmpDir = fullfile(tempdir, 'smoke_m12');
if isfolder(tmpDir), rmdir(tmpDir, 's'); end
mkdir(tmpDir);
cleanup = onCleanup(@() rmdir(tmpDir, 's'));

% --- Case1: Valid PDF ---
goodPdf = fullfile(tmpDir, 'good.pdf');
fid = fopen(goodPdf, 'w');
fwrite(fid, '%PDF-1.4 dummy content');
fwrite(fid, repmat('x', 1, 2000));
fclose(fid);
r1 = validate_pdf_quality(string(goodPdf));
assert(r1.status == "valid", "Case1 failed: expected valid, got " + r1.status);
fprintf("[PASS] Case1: 正常PDF → valid (filesize=%d)\n", r1.filesize);

% --- Case2: 0-byte file ---
emptyPdf = fullfile(tmpDir, 'empty.pdf');
fid = fopen(emptyPdf, 'w');
fclose(fid);
r2 = validate_pdf_quality(string(emptyPdf));
assert(r2.status == "failed_auto_0kb", "Case2 failed: expected failed_auto_0kb, got " + r2.status);
fprintf("[PASS] Case2: 0バイト → failed_auto_0kb\n");

% --- Case3: 500-byte file (<1KB) ---
smallPdf = fullfile(tmpDir, 'small.pdf');
fid = fopen(smallPdf, 'w');
fwrite(fid, '%PDF-1.4');
fwrite(fid, repmat('x', 1, 492));  % total ~500 bytes
fclose(fid);
r3 = validate_pdf_quality(string(smallPdf));
assert(r3.status == "failed_auto_0kb", "Case3 failed: expected failed_auto_0kb, got " + r3.status);
fprintf("[PASS] Case3: 500バイト → failed_auto_0kb (filesize=%d)\n", r3.filesize);

% --- Case4: 2KB file without PDF header ---
corruptPdf = fullfile(tmpDir, 'corrupt.pdf');
fid = fopen(corruptPdf, 'w');
fwrite(fid, 'NOT_A_PDF_FILE');
fwrite(fid, repmat('y', 1, 2000));
fclose(fid);
r4 = validate_pdf_quality(string(corruptPdf));
assert(r4.status == "failed_auto_corrupt", "Case4 failed: expected failed_auto_corrupt, got " + r4.status);
fprintf("[PASS] Case4: 不正ヘッダ → failed_auto_corrupt\n");

% --- Case5: File not found ---
r5 = validate_pdf_quality(fullfile(tmpDir, "nonexistent.pdf"));
assert(r5.status == "failed_auto_corrupt", "Case5 failed: expected failed_auto_corrupt, got " + r5.status);
fprintf("[PASS] Case5: ファイル不在 → failed_auto_corrupt\n");

fprintf("\n=== test_pdf_validation_smoke: ALL PASSED ===\n");
end
