%% find data

D = 'asc_data/'; % directory with asc data, put converted data here.

F = dir([D '*.asc']);
nF = size(F,1);


%% process data

for idx = 1:nF % process each file in the directory D
    filename = [D F(idx).name];
    disp(filename)
    read_el_sp(filename);
end