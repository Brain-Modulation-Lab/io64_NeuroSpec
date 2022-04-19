function portObj = io64(object, address, data)
%simple wrapper to use NeuroSpec trigger box using io64 API
%AB 20210515
%ubuntu: make sure permissions are set for usb port (eg /dev/ttyACM0)
%ubuntu: specify usb device in ~/Documents/MATLAB/usbdev.txt
%ubuntu: create ~/Documents/MATLAB/port.txt with 0


if (nargin ==0) %initial call to io64, openning port
    if isunix()
        userdir = '~';
        usbDevFile = fullfile(userdir, 'Documents', 'MATLAB', 'usbdev.txt');
        if exist(usbDevFile, 'file') == 2  % get the device from a specified text file
            port_name = strtrim(fileread(usbDevFile));
        else
            portlist = get_port_list();
            port_name = portlist{1,2};
        end
    else 
        userdir = getenv('USERPROFILE');
        portFile = fullfile(userdir, 'Documents', 'MATLAB', 'port.txt');
        if exist(portFile, 'file') == 2  % get the port from a specified text file
            port_name = ['COM' fileread(portFile)];
        else
            port_name = 'COM3';
        end
    end
    portObj=[];
    portObj.port_handle = serial(port_name);    
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
        

