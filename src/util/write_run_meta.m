function write_run_meta(filePath, meta)
%WRITE_RUN_META  Writes a unified run_meta.json file (M17).
%
%   write_run_meta(filePath, meta)
%
%   Outputs a run_meta.json shared by pipeline and batch runs.
%   Consolidates front_run_summary.json / run_manifest.json into a single metadata file.
%
%   The caller builds required/optional fields in the meta struct.
%   This function auto-adds schema_version and created_at, then writes PrettyPrint JSON.
%
%   Example:
%     meta = struct();
%     meta.run_id = ctx.run_id;
%     meta.run_dir = ctx.run_dir;
%     meta.mode = "pipeline";
%     meta.status = "completed";
%     write_run_meta(ctx.run_meta_json, meta);

arguments
    filePath (1,1) string
    meta (1,1) struct
end

meta.schema_version = "2.1";
if ~isfield(meta, 'created_at') || strlength(string(meta.created_at)) == 0
    meta.created_at = string(datetime('now', 'Format', 'yyyy-MM-dd''T''HH:mm:ss'));
end

outDir = fileparts(filePath);
if strlength(outDir) > 0 && ~isfolder(outDir)
    mkdir(outDir);
end

text = jsonencode(meta, PrettyPrint=true);
fid = fopen(filePath, 'w');
if fid < 0
    error("write_run_meta:OpenFailed", "Failed to write run_meta.json: %s", filePath);
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fwrite(fid, char(text), 'char');
end
