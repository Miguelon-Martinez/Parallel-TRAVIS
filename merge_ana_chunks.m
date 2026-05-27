function final_file = merge_ana_chunks(input_file, ana_chunks_dir, final_dir, n_header_lines)
% Junta archivo_c1_ana.dat, archivo_c2_ana.dat, ...
% y genera archivo_ana.dat con el nombre del input original.

if nargin < 2 || isempty(ana_chunks_dir)
    ana_chunks_dir = 'output_chunks';
end

if nargin < 3 || isempty(final_dir)
    final_dir = pwd;
end

if nargin < 4 || isempty(n_header_lines)
    n_header_lines = 0;
end

if ~exist(final_dir, 'dir')
    mkdir(final_dir);
end

[~, base_name, ext_name] = fileparts(input_file);

final_file = fullfile(final_dir, [base_name, '_ana', ext_name]);

pattern = fullfile(ana_chunks_dir, [base_name, '_c*_ana', ext_name]);
chunk_info = dir(pattern);

if isempty(chunk_info)
    error('No se encontraron archivos %s_c*_ana%s en %s', ...
        base_name, ext_name, ana_chunks_dir)
end

chunk_numbers = zeros(numel(chunk_info), 1);

for k = 1:numel(chunk_info)
    expr = ['^', regexptranslate('escape', base_name), '_c(\d+)_ana', ...
            regexptranslate('escape', ext_name), '$'];

    tok = regexp(chunk_info(k).name, expr, 'tokens', 'once');

    if isempty(tok)
        error('Nombre de chunk no reconocido: %s', chunk_info(k).name)
    end

    chunk_numbers(k) = str2double(tok{1});
end

[~, idx] = sort(chunk_numbers);
chunk_info = chunk_info(idx);

fid_out = fopen(final_file, 'w');

if fid_out < 0
    error('No se pudo crear el archivo final: %s', final_file)
end

cleanupObj = onCleanup(@() fclose(fid_out));

for k = 1:numel(chunk_info)

    chunk_path = fullfile(ana_chunks_dir, chunk_info(k).name);

    fid_in = fopen(chunk_path, 'r');

    if fid_in < 0
        error('No se pudo abrir el chunk: %s', chunk_path)
    end

    line_number = 0;
    tline = fgetl(fid_in);

    while ischar(tline)

        line_number = line_number + 1;

        if k == 1 || line_number > n_header_lines
            fprintf(fid_out, '%s\n', tline);
        end

        tline = fgetl(fid_in);
    end

    fclose(fid_in);

    fprintf('Añadido: %s\n', chunk_path)

end

fprintf('\nArchivo final creado: %s\n', final_file)

end