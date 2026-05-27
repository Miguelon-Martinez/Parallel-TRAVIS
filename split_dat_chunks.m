function chunk_files = split_dat_chunks(File_in, WorkDir, n_header_lines, n_chunks)
% Divide un .dat en n_chunks y los guarda en:
%
% work/
%   input/
%     archivo.dat
%   chunks/
%     chunk_0001.dat
%     chunk_0002.dat
%     ...
%   output_chunks/
%   logs/

if nargin < 2 || isempty(WorkDir)
    WorkDir = fullfile(pwd, 'work');
end

if nargin < 3 || isempty(n_header_lines)
    n_header_lines = 0;
end

if nargin < 4 || isempty(n_chunks)
    n_chunks = 4;
end

input_dir = fullfile(WorkDir, 'input');
chunks_dir = fullfile(WorkDir, 'chunks');
output_chunks_dir = fullfile(WorkDir, 'output_chunks');
logs_dir = fullfile(WorkDir, 'logs');

if ~exist(input_dir, 'dir'), mkdir(input_dir); end
if ~exist(chunks_dir, 'dir'), mkdir(chunks_dir); end
if ~exist(output_chunks_dir, 'dir'), mkdir(output_chunks_dir); end
if ~exist(logs_dir, 'dir'), mkdir(logs_dir); end

if nargin < 1 || isempty(File_in)
    [FileName, PathName] = uigetfile('*.dat', 'Selecciona archivo .dat');
    if isequal(FileName, 0)
        error('No se seleccionó ningún archivo.')
    end
    File_in = fullfile(PathName, FileName);
end

[~, base_name, ext_name] = fileparts(File_in);

input_copy = fullfile(input_dir, [base_name, ext_name]);

if ~strcmp(char(java.io.File(File_in).getCanonicalPath()), char(java.io.File(input_copy).getCanonicalPath()))
    copyfile(File_in, input_copy);
end

fid = fopen(input_copy, 'r');
if fid < 0
    error('No se pudo abrir el archivo: %s', input_copy)
end

lines = {};
tline = fgetl(fid);
while ischar(tline)
    lines{end+1, 1} = tline;
    tline = fgetl(fid);
end
fclose(fid);

if n_header_lines > numel(lines)
    error('n_header_lines es mayor que el número total de líneas.')
end

header_lines = lines(1:n_header_lines);
data_lines = lines(n_header_lines+1:end);

n_rows = numel(data_lines);
chunk_files = cell(n_chunks, 1);

for k = 1:n_chunks

    i_start = floor((k-1) * n_rows / n_chunks) + 1;
    i_end = floor(k * n_rows / n_chunks);
    
    [~, input_base, input_ext] = fileparts(File_in);

    chunk_name = sprintf('%s_c%d%s', input_base, k, input_ext);
    chunk_path = fullfile(chunks_dir, chunk_name);

    fid = fopen(chunk_path, 'w');
    if fid < 0
        error('No se pudo crear el chunk: %s', chunk_path)
    end

    for ih = 1:numel(header_lines)
        fprintf(fid, '%s\n', header_lines{ih});
    end

    for il = i_start:i_end
        fprintf(fid, '%s\n', data_lines{il});
    end

    fclose(fid);

    chunk_files{k} = chunk_path;

    fprintf('chunk_%04d: filas %d-%d -> %s\n', k, i_start, i_end, chunk_path)

end

fprintf('\nChunks creados en: %s\n', chunks_dir)

end