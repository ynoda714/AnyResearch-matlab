function result = validate_pdf_quality(localPath)
% validate_pdf_quality - Quality validation for downloaded PDFs
%
%   Performs a 3-stage inspection and returns the status of the first detected issue.
%     1. File size check: < 1KB -> failed_auto_0kb
%     2. PDF integrity check: verify %PDF- header -> failed_auto_corrupt
%     3. If the above checks pass, return valid
%
%   Input:
%     localPath (string) - Local PDF file path
%
%   Output (struct):
%     .status  : "valid" | "failed_auto_0kb" | "failed_auto_corrupt"
%     .message : Inspection message
%     .filesize : File size (bytes)
arguments
    localPath (1,1) string
end

result = struct('status', "valid", 'message', "", 'filesize', int64(0));

if ~isfile(localPath)
    result.status  = "failed_auto_corrupt";
    result.message = "file does not exist";
    return;
end

% --- 1. File size check ---
d = dir(localPath);
result.filesize = int64(d.bytes);
if d.bytes < 1024
    result.status  = "failed_auto_0kb";
    result.message = sprintf("file too small: %d bytes (threshold=1024)", d.bytes);
    return;
end

% --- 2. PDF header integrity check ---
fid = fopen(localPath, 'r');
if fid < 0
    result.status  = "failed_auto_corrupt";
    result.message = "cannot open file";
    return;
end
header = fread(fid, 5, '*char')';
fclose(fid);

if numel(header) < 5 || ~strcmp(header, '%PDF-')
    result.status  = "failed_auto_corrupt";
    result.message = sprintf("invalid PDF header: '%s'", header);
    return;
end

end
