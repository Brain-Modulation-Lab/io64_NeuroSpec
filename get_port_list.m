 function ttyList = get_port_list(verbose)
%GET_PORT_LIST Returns a list of serial ports with devices connected
% TTYLIST = GET_PORT_LIST(VERBOSE) returns a list of serial port
%  names which are suitable for connections with serial port objects.
%  The devices are assumed to be USB devices (either a USB-serial
%  converter or a device with a compatible interface, like an Arduino).
%
%   TTYLIST     Results are returned in a 2xN cell array:
%                   {Device Identifier},{Full /dev port or COM port Name}
%
%   VERBOSE     Level of printed messages, 0-2. Default 1.
%
%  This function is cross-platform. On Windows, the returned serial port
%   names are COM ports, e.g. 'COM5'. On OS X or Linux, the port names are
%   device names such as "/dev/tty.usbserial-ABC'. In either case, the
%   string in column 2 of TTYLIST can be used to create a SERIAL object in
%   Matlab. The string in column 1 is a device identifier. On Windows, it
%   is the COM port number. On OS X / Linux, it is a string assigned by the
%   device driver. On Windows, the port list is returned sorted by COM port
%   number, with the highest number first (descending order).
%
%  This function represents the simplest way to get the list of available
%   serial ports. There are more sophisticated ways of inspecting your
%   device tree on OS X and Linux using system commands, and the most
%   reliable method is to use the USB API provided by the manufacturer of
%   your device. If you need more detailed information (like "which device
%   is the Arduino?"), some hints are given in the comments in the code.
%
%  OS X only: devices that support only the three minimal serial
%   communications pins RX, TX, GND have entries of the form "/dev/cu.X".
%   Devices that support the "full" RS-232 hardware lines have entries of
%   the form "/dev/tty.X". Devices that support the "full" RS-232 also have
%   the basic three pins, and so many devices will have two entries in /dev
%   Whether this happens, or which one gives better performance, depends
%   on the device and the driver.
%
% Example: (on OS X)
%  
%   devices = get_port_list;
%   disp(devices)
%       'A700elGZ'    '/dev/tty.usbserial-A700elGZ'
%       'PXFARNQU'    '/dev/tty.usbserial-PXFARNQU'
%   
%   device_connection = serial(devices{1,2});
%   fopen(device_connection);
%   % send/receive data, etc
%   fclose(device_connection);
%
%
% Matthew Hopcroft
%   hopcroft@reddogresearch.com
%
% NB: Linux only tested on Ubuntu 14.04
% v1.3 Feb2018
%		Include USB and ACM devices on Linux
%		Redo device ID logic for OS X, Linux
%		Cleanup comments and prepare for submission
% v1.2  Apr2017
%		Add support for cu (UART) devices on OS X
% v1.1  Mar2016
if nargin < 1, verbose = 1; end
ttyList={};
portOrder =[];
%% Windows
if ispc
    
    % Get COM port info with system (Windows) mode command 
    if verbose >= 3
        [stat, result] = system('mode', '-echo');
    else
        [stat, result] = system('mode');
    end
    if stat ~= 0
        fprintf(1,'get_port_list: Unable to get device list (error %d)\n',stat);
        return
    end
    
    % identify the COM ports in the output string and format in cell array
    portList = regexp(result,'COM\d+:','match');
    k=0;
    for p = portList
        k=k+1;
        portNum = regexp(p{1},'\d+','match');
        portName = regexp(p{1},'COM\d+','match');
        ttyList = [ttyList; {portNum{1}, portName{1}}];
        if verbose >= 2, fprintf(1,'  Serial Device at %s\n',ttyList{k,2}); end
        portOrder = [portOrder str2num(portNum{1})];
    end
    % return the list sorted with largest number first
    [p2,i]=sort(portOrder,2,'descend');
    ttyList = ttyList(i,:);
    
%% OS X
% This function will return only unix-based device identifiers, which is
%  what MATLAB can use. Note that more detailed information about USB
%  devices is available from OS X with the command:
%   [stat, tty]=system('ioreg -p IOUSB | grep xyz');
%  (for example, xyz = Arduino)
% The /dev name uses the "@" string, with zeroes removed and Port Number
%  (always 1?) appended. To find it, use:
% [s,e]=regexp(tty,'(?<=@)[1-9]+')
elseif ismac
    
    % On OS X, we must be using a USB-based serial adapter of some kind.
	% I have seen two formats of USB device identifiers:
	%   /dev/[tty cu].usbserial-xxxxxxxx
	%   /dev/[tty cu].usbmodemyyyyy
    [stat(1), tty]=system('ls /dev/tty.usb*');
	if verbose >= 2, disp(tty); end
	if stat(1)~=0
        if verbose >= 2, fprintf(1,'get_port_list: Cannot get tty device list (status %d)\n',stat(1)); end
	end
    [stat(2), cu]=system('ls /dev/cu.usb*');
	if verbose >= 2, disp(cu); end
	if stat(2)~=0
        if verbose >= 2, fprintf(1,'get_port_list: Cannot get cu device list (status %d)\n',stat(2)); end
	end
	if ~any(stat==0)
        if verbose >= 1, fprintf(1,'get_port_list: No devices found.\n'); end
		return
	end
	tty = [tty cu];
	if ~isempty(tty)
		% separate result into individual lines
		devList=textscan(tty,'%s'); devList=devList{1};
		for k=1:length(devList)
			% get device identifier
			sp = strfind(devList{k},'.');
			if ~isempty(sp) && sp<length(devList{k})
				usbstr = devList{k}(sp+1:end);
			else
				usbstr = devList{k};
			end
			sp = strfind(usbstr,'-');
			if ~isempty(sp) && sp<length(usbstr)
				usbid = usbstr(sp+1:end);
			else
				usbid = usbstr;
			end			
			% append results to list (cell strings)
			ttyList=[ttyList; usbid, devList(k)];
			if verbose >= 2, fprintf(1,'  USB Serial Device %s at %s\n',ttyList{end,1},ttyList{end,2}); end
		end
	end
			
	if isempty(ttyList)
		fprintf(1,'get_port_list: No devices found! (exit)\n');
		return
	end
	
    
%% Linux
% Note: You can get more information by comparing the entries in 
% '/sys/bus/usb/devices/' and '/sys/bus/usb-serial/devices/'
%  (Debian)
else
    
    % I have seen two formats of entries in /dev for serial devices:
	%   /dev/ACMx
	%   /dev/USBx
	%  where x is an integer starting with 0.
	% If your system uses other formats you may have to change the ls command
    %  (e.g. 'ls /dev/tty*')
    [stat(1), tty]=system('ls /dev/ttyUSB*');
	if stat(1)~=0
        fprintf(1,'get0_port_list: Unable to get USB device list (error %d)\n',stat(1));
        tty=[];
    else
        tty=strtrim(tty);
	end
    [stat(2), ac]=system('ls /dev/ttyACM*');
	if stat(2)~=0
        fprintf(1,'get_port_list: Unable to get ACM device list (error %d)\n',stat(2));
        ac=[];
    else
        ac=strtrim(ac);
	end
	if ~any(stat==0)
        if verbose >= 1, fprintf(1,'get_port_list: No devices found.\n'); end
		return
	end
	tty = [tty ac];
	if ~isempty(tty)
        if verbose >= 3, disp(tty); end       
        % separate result into individual lines
        devList=textscan(tty,'%s'); devList=devList{1};
		for k=1:length(devList)
            % get device identifier
            usbstr = strsplit(devList{k},'-');
            if length(usbstr)==1
                usbstr{2} = usbstr{1}(12:end);
                usbstr{1} = usbstr{1}(1:11);
            end            
            % append results to list (cell strings)
            ttyList=[ttyList; usbstr(2), devList(k)];          
            if verbose >= 2, fprintf(1,'  Serial device %s at %s\n',ttyList{k,1},ttyList{k,2}); end
		end
	end
    
end
%#ok<*AGROW>