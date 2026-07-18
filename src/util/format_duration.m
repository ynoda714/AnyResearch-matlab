function text = format_duration(sec)
%FORMAT_DURATION  Converts seconds to a MM:SS formatted string.
%
%   Usage:
%     text = format_duration(125)   % => "02:05"

sec  = max(0, floor(double(sec)));
mm   = floor(sec / 60);
ss   = mod(sec, 60);
text = string(sprintf('%02d:%02d', mm, ss));
end
