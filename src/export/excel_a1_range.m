function ref = excel_a1_range(row1, col1, row2, col2)
%EXCEL_A1_RANGE  Build an Excel A1 reference from 1-based row/column indices.
arguments
    row1 (1,1) double {mustBeInteger, mustBePositive}
    col1 (1,1) double {mustBeInteger, mustBePositive}
    row2 (1,1) double {mustBeInteger, mustBePositive} = row1
    col2 (1,1) double {mustBeInteger, mustBePositive} = col1
end

startRef = local_cell_ref(row1, col1);
endRef   = local_cell_ref(row2, col2);
if row1 == row2 && col1 == col2
    ref = startRef;
else
    ref = startRef + ":" + endRef;
end
end

function ref = local_cell_ref(row, col)
letters = "";
while col > 0
    remVal = mod(col - 1, 26);
    letters = string(char(double('A') + remVal)) + letters;
    col = floor((col - 1) / 26);
end
ref = letters + string(row);
end
