function excel_apply_header_style(ws, nCols)
%EXCEL_APPLY_HEADER_STYLE  Apply style to the header row (row 1) of a COM worksheet
%
%   excel_apply_header_style(ws, nCols)
%
%   ws    — COM Excel worksheet object
%   nCols — Number of columns to apply style to (columns 1 through nCols)
%
%   Applied style:
%     - Font Bold
%     - Background color #BDD7EE (standard light blue for Excel table headers)
%     - Font size 10pt
%     - Word wrap OFF
%
%   Note: This function is only for environments where COM is available (Windows + Excel).

if nCols <= 0
    return;
end

headerRange = ws.Range(char(excel_a1_range(1, 1, 1, nCols)));

% Bold + background color
% #BDD7EE: R=189, G=215, B=238 → Excel color = R + G*256 + B*65536
headerRange.Font.Bold = true;
headerRange.Interior.Color = int32(189 + 215*256 + 238*65536);
headerRange.Font.Size = 10;
headerRange.WrapText = false;
headerRange.Font.Color = int32(0);  % Black
end
