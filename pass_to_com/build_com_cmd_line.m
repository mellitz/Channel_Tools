function [arg_cell,num_fext,num_next]=build_com_cmd_line(infile)

file_data=text_file_to_cell_lines(infile);
%specification states that first row must be a header
[dat,header]=cell_lines_to_2D_matrix(file_data,',','-header','1');

%column 1=thru, column2=fext, column3=next
%parameter options beyond column 4 are optional
if size(dat,2)>3
    param(1:size(dat,2)-3)=header(4:end);
end

%now find the start indices (when a thru file is used)
start_index=find(~cellfun('isempty',(dat(:,1))));
num_cases=length(start_index);
start_index=[start_index;size(dat,1)+1];

for j=1:num_cases
    this_thru=dat(start_index(j),1);
    search_range=start_index(j):start_index(j+1)-1;
    
    [num_fext(j),this_fext]=variable_dat_search(dat,search_range,2);
    [num_next(j),this_next]=variable_dat_search(dat,search_range,3);
    
    %check for optional params
    my_opt_par={};
    if size(dat,2)>3
        this_val=dat(start_index(j),4:end);
        %only pass params that are non-empty for this case
        val_index=find(~cellfun('isempty',(this_val)));
        my_opt_par(1:2:2*length(val_index)-1)=param(val_index);
        my_opt_par(2:2:2*length(val_index))=this_val(val_index);
    end
    
   
    arg_cell{j}=[this_thru this_fext' this_next' my_opt_par];
        
end
 
end


function [num_x,this_x]=variable_dat_search(dat,search_range,col)

%it is possible that the dat max column size is less than the search column
%return empty data in that scenario
if size(dat,2)<col
    num_x=0;
    this_x={};
else
    valid_x=find(~cellfun('isempty',(dat(search_range,col))));
    num_x=length(valid_x);
    if num_x>0
        this_x=dat(valid_x+search_range(1)-1,col);
    else
        this_x={};
    end
end

end


function file_data=text_file_to_cell_lines(input_file,varargin)

%list of available - flags in varargin
%flag_comment reveals comment character at beginning of line.  like *
flag_comment='comment';
%flag_remove_blank.  if present, blank lines are thrown out
flag_remove_blank='rm_empty';
%flag_continuation reveals end of line string used to signal a line
%continuation.  Like ...
flag_continuation='ln_continue';

[cmd_name,cmd_param]=dash_varg_parser(varargin{:});

fid=fopen(input_file);
[cpass,cidx,cL] = string_find_exact(cmd_name,flag_comment);
if cpass
    if cL>1
        error('Duplicate param specification %s',flag_comment);
    end
    comment_char=cmd_param{cidx};
    file_data=textscan(fid,'%s','Delimiter','\n','CommentStyle',comment_char);
else
    file_data=textscan(fid,'%s','Delimiter','\n');
end
file_data=file_data{1};
fclose(fid);

%remove blank lines
[cpass] = string_find_exact(cmd_name,flag_remove_blank);
if cpass
    L=cellfun('length',file_data);
    file_data=file_data(L~=0);
end

continuation=0;
[cpass,cidx,cL] = string_find_exact(cmd_name,flag_continuation);
if cpass
    if cL>1
        error('Duplicate param specification %s',flag_continuation);
    end
    continuation=1;
    continuation_str=cmd_param{cidx};
    LC=length(continuation_str);
end
if continuation
    x=strfind(file_data,continuation_str);
    %turn it into double array instaed of cell array
    x(cellfun('isempty',x))={NaN};
    x=cell2mat(x);
    %find length of each line minus length of continuation_str+1
    %the +1 is there because the index in x is the starting point of continuation_char
    y=cellfun('length',file_data)-LC+1;
    %where x=y means there is a end of line continuation_char
    z=find(x==y);
    
    for j=1:length(z)
        %find current length of file_data (it will reduce by 1 for each continuation_char)
        L=length(file_data);
        %concatenate line at z(j) with the next line (Also remove continuation_char from z(j) line
        file_data{z(j)}=[file_data{z(j)}(1:end-LC) file_data{z(j)+1}];
        %shift the array up one to reflect that line z(j)+1 is now combined with line z(j)
        file_data(z(j)+1:L-1)=file_data(z(j)+2:L);
        %remove the last line of the array
        file_data(L)=[];
        %if not on the last index of z, subtract 1 from the z array since all future indices have been shifted up
        if(j<length(z))
            z(j+1:end)=z(j+1:end)-1;
        end
    end

end

end


function [out_data,header]=cell_lines_to_2D_matrix(cell_lines,delimiter,varargin)

[cmd_name,cmd_param]=dash_varg_parser(varargin{:});

flag_header_lines='header';




for j=1:length(cell_lines)
    temp=textscan(cell_lines{j},'%s','delimiter',delimiter);
    temp=temp{1};
    out_data(j,1:length(temp))=temp;
end

[cpass,cidx,cL] = string_find_exact(cmd_name,flag_header_lines);
if cpass
    if cL>1
        error('Duplicate param specification %s',flag_header_lines);
    end
    num_header_lines=str2num(cmd_param{cidx});
    header=out_data(1:num_header_lines,:);
    out_data=out_data(num_header_lines+1:end,:);
else
    header={};
end




end


function [name,param]=dash_varg_parser(varargin)
%dash_varg_parser
%This function handles sending name/value pairs from varargin arguments to
%the calling function.
%For example:  -arg1 2 will return name=arg1 and value=2
%arguments don't need values.  -arg1 -arg2 ABC means arg1 is passed with no
%value and arg2 is passwed with value=ABC


name={};
param={};
if ~isempty(varargin)
    %only names that start with - are parsed
    %note that some - params may not have a param associated with it
    %That is okay as it just means the param that gets lumped will be the
    %next - param in the list.  The tool that uses it will know whether or
    %not to grab the param value
    [pass,idx,L] = string_find_regexp(varargin,'^-');
    if pass
        name{L,1}=[];
        param{L,1}=[];
        for j=1:L
            name{j}=varargin{idx(j)}(2:end);
            %only check for param is to avoid overflow in case the last
            %name doesn't use a param value
            if length(varargin)>=idx(j)+1
                param{j}=varargin{idx(j)+1};
            else
                param{j}='';
            end
        end
    end
end

end



function [pass,idx,L] = string_find_regexp(my_strings,this_reg)
%string_find_regexp
%This function finds the index of a string within a cell array of strings
%It looks for a regular expression match
%If no match is found, the pass output is set to 0 and all other outputs are 0
%If a match is found, idx returns the location in my_strings of those matches.
%If a match is found, L is the number of indices returned.



tmp_idx=find(~cellfun('isempty',regexp(my_strings,this_reg)));
[pass,idx,L]=string_find_returns(tmp_idx);

end


function [pass,idx,L] = string_find_exact(my_strings,target)
%string_find_exact
%This function finds the index of a string within a cell array of strings
%It looks for exact match (case senstive)
%If no match is found, the pass output is set to 0 and all other outputs are 0
%If a match is found, idx returns the location in my_strings of those matches.
%If a match is found, L is the number of indices returned.


tmp_idx=find(strcmp(my_strings,target));
[pass,idx,L]=string_find_returns(tmp_idx);

end


function [pass,idx,L]=string_find_returns(in_idx)

if isempty(in_idx)
    pass=0;
    idx=0;
    L=0;
else
    pass=1;
    idx=in_idx;
    L=length(idx);
end


end




