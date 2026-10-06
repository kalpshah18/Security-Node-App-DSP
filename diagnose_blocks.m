function diagnose_blocks()
load_system('simulink');
disp('--- Dashboard blocks ---');
disp(find_system('simulink/Dashboard','SearchDepth',1,'Type','Block'));
disp('--- Android / iOS library files ---');
root = '';
try, root = matlabshared.supportpkg.getSupportPackageRoot; catch, end
disp(root);
f = dir(fullfile(root,'**','*.slx'));
for i = 1:numel(f)
    full = fullfile(f(i).folder,f(i).name);
    if contains(lower(full),'android') && contains(lower(f(i).name),'lib')
        fprintf('\nLIB: %s\n', full);
        try
            load_system(full);
            [~,n] = fileparts(f(i).name);
            b = find_system(n,'SearchDepth',2,'Type','Block');
            fprintf('  %s\n', b{:});
        catch ME, disp(ME.message); end
    end
end
end