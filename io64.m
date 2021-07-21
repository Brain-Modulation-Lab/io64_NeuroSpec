function portObj = io64(object, address, data)
%simple wrapper to use NeuroSpec trigger box using io64 API
%AB 20210515

if (nargin ==0) %initial call to io64, openning port
    portFile = fullfile(getenv('USERPROFILE'), 'Documents', 'MATLAB', 'port.txt');
    if exist(portFile, 'file') == 2  % get the port from a specified text file
        port_nb = fileread(portFile);
    else
        port_nb = '3';
    end
    portObj=[];
    portObj.port_handle = serial(['COM' port_nb]);
    set(portObj.port_handle,'BaudRate',9600); % 9600 is recommended by Neurospec
    fopen(portObj.port_handle);
    portObj.oncleanup = onCleanup(@() fclose(portObj.port_handle));
    
elseif(nargin==1) %getting status
    if strcmp(object.port_handle.Status,'open')
        portObj = 0;
    else
        portObj = 1;
    end
    return
    
elseif(nargin==3)
    fwrite(object.port_handle,data)
else
    portObj=[];
end
        

