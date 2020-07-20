function pass_to_com(infile,config,results_tag,Thru_only,ver,range)
% 2020 (c) Samtec, Inc. 
% Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
% Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
% Neither the name of Samtec Inc. nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
% Samtec makes no warranty or guarantee as to the suitability of the software or code for any specific application. Samtec reserves the right to make changes at any time without further notice.  By downloading software/code, the User agrees to all of the terms contained herein and to absolve Samtec from all liability related to the use, installation, execution or application of the software/code. The software/code is provided for the limited purpose of evaluating mathematical methods or metric calculations. Samtec does not grant express or implied rights or license under any patent, copyright, trademark or other proprietary rights. Decryption of any software/code is expressly prohibited.  The use of the software/code for building, reverse engineering or replication of any parts or any software/code is strictly prohibited. By using this software/code, the User agrees to not infringe, directly or indirectly, upon any intellectual property rights of Samtec and acknowledges that Samtec, its various licensors, or both own all intellectual property therein. The software/code is presented "AS IS". While Samtec makes every effort to present excellent information, it does not warrant the software/code is without error or defect or warrant the use of the software/code/encrypted model in terms of accuracy, reliability or otherwise. The User agrees that all access, use, installation or execution of the software/code at its own risk. NO WARRANTIES EXPRESSED OR IMPLIED, INCLUDING ANY WARRANTY OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE OR OF ANY KIND WHATSOEVER ARE PROVIDED.
% 
% 
% Author: Richard Mellitz
% pass-to_com version
p2cv=2.0;
sprintf('pass 2 com version %g',p2cv)
% Infile is the csv list
% config is the com configuration xls file. parameter may be altered by the csv file
% results_tag is a string for added to the date string for com results mat file
% Thru_only is either 0 or 1. 1 means do not compute COM with crosstalk
% range is string which specifies what cases in the csv file to run
% ver is the COM version to run
% example:
%   pass_to_com('KR_BIGLIST.csv','config_com_ieee8023_93a=100GEL-temp.xls','test',0,'24',264)
if ~exist('ver','var')
    ver='265';
end
if ~exist('results_tag','var')
    results_tag='_channels_results';
end
if ~exist('Thru_only','var')
    Thru_only=0;
end
addpath('C:\Users\richardm\OneDrive - Samtec\COM\WIP\') ;

RESULT_DIR=[ './results/Pass2Com_' date '/'];
if ~exist(RESULT_DIR,'dir'); mkdir(RESULT_DIR); end
com_call=str2func(sprintf('com_ieee8023_93a_%s',ver));
ir=1;kk=1; missed=[]; ranlist=[]; results=[];
[arg_cell,num_fext,num_next]=build_com_cmd_line(infile);
if ~exist('range','var')
    range=1:length(arg_cell);
else
    range=eval(range);
end
data_str=date;

for ii=1:length(range)
    jj=range(ii);
    display(sprintf('itteration %g case %g ',ii ,jj));
    varg_to_pass=arg_cell{jj};    
    if Thru_only
        % omit next and fext but leave options
        varg_to_pass = {varg_to_pass{1} varg_to_pass{(num_fext(jj)+num_next(jj)+2):length(varg_to_pass)} };
        num_fext(jj)=0;
        num_next(jj)=0;
    end
    try
        results{jj}=com_call(config,num_fext(jj),num_next(jj),varg_to_pass{:});
        save([ RESULT_DIR data_str results_tag '.mat'],'results','missed','ranlist')
    catch
        err=lasterror;
        kk=kk+1;
        display(sprintf('failed to execute itteration %g case %g ',ii ,jj));
        display(err.message);
        missed(kk).index= [ ii jj ];
        missed(kk).err_msg= err.message;
        continue
    end
    ranlist(ir).index = [ ii jj ];
    ir=ir+1;
end
%results_table=cellfun(@(x) x(1),results);
save([ RESULT_DIR data_str results_tag '.mat'],'results','missed','ranlist')
% use this when WFH
% try 
% save([ '\\na-hpc-fs1\datavol1\sig\users\Rich_Mellitz\IEEE\IEEE802.3ck\COM\' date results_tag '.mat'],'results')
% catch
% end
end