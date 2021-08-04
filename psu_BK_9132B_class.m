classdef psu_BK_9132B_class<handle
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Class for BK Precision 9132B Programmable DC power supply 				%
% 																			%
%%% Methods: 																%
%		- init(resource)				// Open device connection 			%
%		- reset()						// Reset to default 				%
%		- rawWrite(comm)				// Write given command on SCPI 		%
%		- data = rawWR(comm) 												%
%		- 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

	properties
		visaObj
		trackopt % Enable/Disable all tracked outputs if track is enabled
		lastchan % Store last channel
	end
	methods
		function res = init(obj, resource)
			% Init resource
			try
				obj.visaObj = visadev(resource);
			catch
				error("Problem in connecting to visa instrument");
			end

			idn = writeread(obj.visaObj, "*IDN?");
			disp(strcat("Connected with: ", idn));

			obj.trackopt = 0;
			obj.lastchan = 0;

			res = true;
		end

		function rawWrite(obj, comm)
			% Interface for visadev writeline function
			% INPUT: string -> command to be sent

			writeline(obj.visaObj, comm);
		end

		function data = rawWR(obj, comm)
			% Interface for visadev writeline function
			% INPUT: string -> command to be sent
			% OUTPUT: string -> response from instrument

			data = writeread(obj.visaObj, comm);
		end

		function waitForOPC(obj)
			% Block execution until psu is ready
			K=0;
			while(K~=1)   
			    K = str2double(writeread(obj.visaObj, "*OPC?"));
			end
		end

		% Get idn of device
		function r = idn(obj)
			r = writeread(obj.visaObj, "*IDN?");
		end

		function reset(obj)
			% Reset PSU to initial value
			% - Perform a *RST command

			obj.rawWrite('*RST');
		end

		function setVoltage(obj, chan, voltage)
			% Set channel to target voltage 
			% args:
			%   chan: integer 1-3
			%	voltage: integer
			% If chan is not provided, operations would be in current channel

			if nargin<3
				voltage = chan;
				chan = 0;
			else
				obj.lastchan = chan;
			end

			if chan == 0
				obj.rawWrite(strcat("VOLT ", num2str(voltage)));
			else
				obj.rawWrite(strcat("INST CH", num2str(chan)));
				obj.rawWrite(strcat("VOLT ", num2str(voltage)));
			end
		end

		function setCurrent(obj, chan, current)
			% Set channel to target current 
			% args:
			%   chan: integer 1-3
			%	current: integer
			% If chan is not provided, operations would be in current channel
			
			if nargin<3
				current = chan;
				chan = 0;
			else
				obj.lastchan = chan;
			end

			if chan == 0
				obj.rawWrite(strcat("CURR ", num2str(current)));
			else
				obj.rawWrite(strcat("INST CH", num2str(chan)));
				obj.rawWrite(strcat("CURR ", num2str(current)));
			end
		end

		function setTrack(obj, onoff)
			% Enable/Disable track function on channel

			if isa(onoff, 'integer') || isa(onoff, 'double')
				if onoff == 1
					onoff = "ON";
				else
					onoff = "OFF";
				end
			else
				if ~ismember(onoff, ["ON" "OFF"])
					onoff = "OFF";
				end
			end

			if onoff == "ON"
				obj.trackopt = 1;
			else
				obj.trackopt = 0;
			end
			obj.lastchan = 2;

			obj.rawWrite(strcat(":OUTP:TRAC CH2,", onoff));
		end

		function setOnOff(obj, chan, state)
			% Set channel on/off
			% args:
			%   chan: integer 1-3
			%	state: integer {0|1}
			% If chan is not provided, operations would be in current channel
			
			if nargin<3
				state = chan;
				chan = 0;
			end

			% If state is "ON" or "OFF" convert to integer
			if isa(state, 'string') || isa(state, 'char')
				if ismember(state, ["ON" "OFF"])
					if state == "ON"
						state = 1;
					else
						state = 0;
					end
				else
					error("Wrong command in setOnOff()");
				end
			end

			if state == 1
				if chan ~= 0
					if ismember(obj.lastchan, [2 3])
						obj.rawWrite(":OUTP CH3,ON");
						obj.rawWrite(":OUTP CH2,ON");
					else
						obj.rawWrite(strcat(":OUTP CH", num2str(chan), ",ON"));
					end
					obj.lastchan = chan;
				else
					if ismember(obj.lastchan, [2 3])
						obj.rawWrite(":OUTP CH2,ON");
						obj.rawWrite(":OUTP CH3,ON");
					else
						obj.rawWrite(":OUTP ON");
					end
				end
			else
				if chan ~= 0
					if ismember(obj.lastchan, [2 3])
						obj.rawWrite(":OUTP CH3,OFF");
						obj.rawWrite(":OUTP CH2,OFF");
					else
						obj.rawWrite(strcat(":OUTP CH", num2str(chan), ",OFF"));
					end
					obj.lastchan = chan;
				else
					if ismember(obj.lastchan, [2 3])
						obj.rawWrite(":OUTP CH2,OFF");
						obj.rawWrite(":OUTP CH3,OFF");
					else
						obj.rawWrite(":OUTP OFF");
					end
				end
			end
		end

		function [v, c, p] = measAll(obj, chan)
			% Measure voltage, current and power of given channel
			% args:
			%   chan: integer 1-3
			% If chan is not provided, operations would be in current channel

			if nargin<2
				chan = 0;
			end

			if chan == 0
				meas = obj.rawWR(":MEAS:ALL?");
			else
				meas = obj.rawWR(strcat(":MEAS:ALL? CH", num2str(chan)));
			end

			meas = split(meas, ",", 2);
			v = meas(1);
			c = meas(2);
			p = meas(3);
		end
	end
end