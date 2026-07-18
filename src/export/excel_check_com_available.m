function ok = excel_check_com_available()
%EXCEL_CHECK_COM_AVAILABLE  Check whether the Excel COM server is available
%
%   ok = excel_check_com_available()
%
%   Returns true on Windows with Microsoft Excel installed.
%   Returns false otherwise (Linux / macOS / Excel not installed).

try
    excel = actxserver('Excel.Application');
    excel.Quit;
    excel.delete;
    ok = true;
catch
    ok = false;
end
end
