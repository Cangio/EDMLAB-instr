classdef scope_Agi_DSO9254A_class<handle
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Class for DSO9254A scope 													%
%																				%
%%% Methods:																	%
%		- init(resource)				// Open device Connection 				%
%		- reset()						// Reset to default 					%
%		- rawWrite(comm)				// Write given command on SCPI 			%
%		- data = rawWR(comm)			// Write command and get output 		%
%		- waitForOPC() 															%
%		- idn()							// Return IDN of device 				%
%		- setTrigger(chan, varargin)	// Set trigger channel, level, slope 	%
%		- dispChannel(chan)				// Display one given channel 			%
%		- dispChannels(chans)			// Display multiple channels  			%
%		- setTimeDiv(time)				// Set time division 					%
%		- setTimeFromFreq(freq)			// Set time division from freq 			%
%		- setVertDiv(chan, div)			// Set vertical division				%
%		- runStop(run)					// Run/stop operation 					%
%		- setSN(sampling, points)		// Set sampling rate and # points 		%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

	properties
		visaObj
		timeDiv
		sysLoc
		folder
		nchans 	% Total number of channels
		maxSR 	% MAX Sampling Rate
		srs 	% Possible values for Sampling Rate
	end
	methods
		function res = init(obj, resource, folder)
			% Init resource
			try
				obj.visaObj = visadev(resource);
			catch
				error("Problem in connecting to visa instrument");
			end

			idn = writeread(obj.visaObj, "*IDN?");
			disp(strcat("Connected with: ", idn));

			obj.timeDiv = 1e-4;
			obj.nchans = 4;
			obj.maxSR = 4e9;
			obj.srs = [10e6 25e6 50e6 100e6 250e6 0.5e9 1e9 2e9 4e9];

			if nargin < 3
				folder = "Test";
			end
			obj.sysLoc = strcat("C:\DataDownload\", folder, "\");
			obj.folder = folder;

			res = true;
		end

		function reset(obj)
			% Reset oscilloscope to initial value
			% - Perform a *RST command
			% - Set time ref to center to a defined scale
			% - Set all channels OFF in 1Meg impedance

			obj.rawWrite('*RST');
			obj.rawWrite(":TIM:RANGe 1E-3");
			obj.rawWrite(":TIM:DELay 0");
			obj.rawWrite(":TIM:REF CENTer");
			obj.rawWrite(":WAV:FORM WORD;BYT LSBF;STR OFF");

			setSN(obj, 10e9, 1e4);
			waitForOPC(obj);

			% Set 1Meg impedance
			obj.rawWrite("CHAN1:INP DC");
			obj.rawWrite("CHAN2:INP DC");
			obj.rawWrite("CHAN3:INP DC");
			obj.rawWrite("CHAN4:INP DC");
			waitForOPC(obj);

			offAllChan(obj);
			waitForOPC(obj);
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
			% Block execution until scope is ready
			K=0;
			while(K~=1)   
			    K = str2double(writeread(obj.visaObj, "*OPC?"));
			end
		end

		function r = idn(obj)
			% Get the IDN of instrument
			r = writeread(obj.visaObj, "*IDN?");
		end

		function isChan = checkChan(obj, chan)
			% Check if provided channel is available for instrument
			if isa(chan, 'string') || isa(chan, 'char')
				chan = str2double(chan);
			end
			% Check if valid channel
			if ~ismember(chan, [0:obj.nchans])
				isChan = false;
			else
				isChan = true;
			end
		end

		function setTrigger(obj, chan, varargin)
			% Set the scope EDGE mode trigger
			% INPUT:
			%   chan: integer 0-4
			%		CH0: Trigger source AUX
			%		CHx
			%	level: float
			%	r_f: [-1|0|1]
			%		set falling|either|rising edge of trigger

			if obj.checkChan(chan) == false and false
				error("Not a valid channel");
			end
			schan = int2str(chan);

			% Optional arguments are trig_voltage and ris/fal edge
			optargs = {0.0 1};
			if nargin > 2
				optargs(1:(nargin-2)) = varargin;
			end
			[level r_f] = optargs{:};
			slevel = num2str(level);

			
			writeline(obj.visaObj, ":TRIGger:SWEep NORMal");
			
			% Set source channel
			if chan == 0
				writeline(obj.visaObj, ":TRIG:EDGE:SOUR AUX");
				writeline(obj.visaObj, strcat(":TRIG:LEV AUX, ", slevel));
			else
				writeline(obj.visaObj, strcat(":TRIGger:EDGE:SOUR CHAN", schan));
				writeline(obj.visaObj, strcat(":TRIGger:LEVel CHAN", schan, ", ", slevel));
			end

			% Set trigger edge
			switch r_f
				case 1
					sr_f = "POS";	% Trigger for POSitive edge
				case 0
					sr_f = "EITH"; 	% Trigger for EITHer edge
				case -1
					sr_f = "NEG";	% Trigger for NEGative edge
				otherwise
					sr_f = "POS";
			end
			writeline(obj.visaObj, strcat(":TRIGger:EDGE:SLOP ", sr_f));
		end

		function setTrigDelay(obj, dela)
			writeline(obj.visaObj, strcat(":TRIGger:DELay:TDELay:TIME ", num2str(dela)));
		end

		function dispChannelSolo(obj, chan)
			% Set scope to display desired channel (other would be off)
			% INPUT:
			%   chan: integer 1-4

			if checkChan(chan) == 1
				error("Not a valid channel");
			end

			% Enable display of only the selected channel
			for i=1:4
				if chan == i
					obj.rawWrite(strcat(":CHAN", int2str(i), ":DISP ON"));
				else
					obj.rawWrite(strcat(":CHAN", int2str(i), ":DISP OFF"));
				end
			end
		end

		function dispChannel(obj, chan, onoff)
			% Enable/Disable given channel
			% INPUT:
			%   chan: integer 1-4

			if obj.checkChan(chan) == 1
				error("Not a valid channel");
			end
			schan = int2str(chan);
			if onoff == 1
				obj.rawWrite(strcat(":CHAN", schan, ":DISP ON"));
			else
				obj.rawWrite(strcat(":CHAN", schan, ":DISP OFF"));
			end
		end

		function dispChannels(obj, chan)
			% Set scope to display desired channels
			% Multiple channels allowed
			% args:
			%   chan: array of integers 1-4

			% Enable display of only the selected channel
			for i=1:4
				if ismember(i, chan)
					writeline(obj.visaObj, strcat(":CHAN", int2str(i), ":DISP ON"));
				else
					writeline(obj.visaObj, strcat(":CHAN", int2str(i), ":DISP OFF"));
				end
			end
		end

		function obj = setTimeDiv(obj, time)
			% Set time division
			
			time = time * 10;
			obj.timeDiv = time;
			writeline(obj.visaObj, strcat(":TIM:RANGe ", num2str(obj.timeDiv)));
		end

		function obj = setTimePer(obj, time)
			% Set time period
			
			obj.timeDiv = time / 10;
			writeline(obj.visaObj, strcat(":TIM:RANGe ", num2str(obj.timeDiv)));
		end

		% Set time division from frequency
		function obj = setTimeFromFreq(obj, freq)
			time = (1 / freq) * 6;
			obj.timeDiv = time;
			writeline(obj.visaObj, strcat(":TIM:RANGe ", num2str(obj.timeDiv)));
		end

		function setVertDiv(obj, chan, div)
			% Set vertical div for a channel
			% INPUT:
			%   chan: integer or array 1-4
			%	div: float (in V)

			if isa(chan, 'string') || isa(chan, 'char')
				chan = str2double(char);
			end
			if isa(div, 'string') || isa(div, 'char')
				div = str2double(div);
			end

			for i=1:length(chan)
				ran = div(i) * 8; % Compute range from div
				writeline(obj.visaObj, strcat("CHAN", num2str(chan(i)), ":RANGE ", num2str(ran)));
			end
		end

		function runStop(obj, run)
			% Run/stop scope acquisition
			% args:
			%   run: integer {0|1}
			
			if run == 1
				writeline(obj.visaObj, ":RUN");
			else
				writeline(obj.visaObj, ":STOP");
			end
		end

		function setSN(obj, samp, pts)
			% Set sampling rate and # of points to acquire
			% args:
			%   samp: integer (sampling rate in GSa/s)
			%	pts: integer (# of points)
			
			if samp > obj.maxSR
				samp = obj.maxSR;
			end
			writeline(obj.visaObj, strcat(":ACQ:SRAT ", num2str(samp)));
			writeline(obj.visaObj, strcat(":ACQ:POIN ", num2str(pts)));
		end

		function setAutoSN(obj, pts)
			% Auto set sampling rate given # of points and time division
			% args:
			%	pts: integer (# of points)
			
			if ~isnumeric(obj.timeDiv)
				error("Need to call setTimeDiv before");
			end

			rate = pts / obj.timeDiv;
			setSN(obj, rate, pts);
		end

		function setAvrAcq(obj, onoff, cnt)
			if onoff == true
				obj.rawWrite(":ACQuire:AVERage ON");
				obj.rawWrite(strcat(":ACQuire:COUNt ", num2str(cnt)));
			else
				obj.rawWrite(":ACQuire:AVERage OFF");
			end
		end


		function data = acquireWFFast(obj, chan)
			writeline(obj.visaObj, ":SYSTEM:HEADER OFF");
			writeline(obj.visaObj, ":ACQUIRE:MODE RTIME");
			writeline(obj.visaObj, ":ACQUIRE:COMPLETE 100");
			writeline(obj.visaObj, strcat(":WAVeform:SOURce CHANNEL", int2str(chan)));
			writeline(obj.visaObj, ":WAVeform:FORMat ASC");
			writeline(obj.visaObj, ":ACQUIRE:COUNT 8");
			%writeline(obj.visaObj, ":ACQUIRE:POINTS 5000");
			writeline(obj.visaObj, strcat(":DIGITIZE CHANNEL", int2str(chan)));
			writeline(obj.visaObj, "*TRG");
			
			writeline(obj.visaObj, strcat(":CHANnel", int2str(chan), ":DISPlay ON"));
			data = writeread(obj.visaObj, ":WAVEFORM:DATA?");
			%writeline(obj.visaObj, "*TRG");

			data = data.split(",");
			data = str2double(data);
		end

		function data = acquireSegmented(obj, chan)
			writeline(obj.visaObj, ":SYSTEM:HEADER OFF");
			writeline(obj.visaObj, ":ACQUIRE:MODE SEGM");
			writeline(obj.visaObj, ":ACQ:SEGM:COUN 5");
			writeline(obj.visaObj, ":ACQUIRE:COMPLETE 100");
			writeline(obj.visaObj, strcat(":WAVeform:SOURce CHANNEL", int2str(chan)));
			writeline(obj.visaObj, ":WAVeform:FORMat ASCii");
			writeline(obj.visaObj, strcat(":DIGITIZE CHANNEL", int2str(chan)));
				writeline(obj.visaObj, strcat(":CHANnel", int2str(chan), ":DISPlay ON"));
			data = writeread(obj.visaObj, ":WAVEFORM:DATA?");
		end

		% Get waveform from scope
		% args:
		%   file: string (filename)
		%	trc: integer trace to get
		% return:
		%	tV: time vector
		%	vV: voltage vector
		function [tV, vV] = loadBinWF(obj, file, trc)
			scopeLocation = strcat("\\192.168.158.14\DataDownload\", obj.folder, "\");
			
			[tV, vV] = importAgilentBin(strcat(scopeLocation, file, ".bin"), trc);
		end

		function data = acquireOnBin(obj, folder, file)
			%writeline(obj.visaObj, ":SYSTEM:HEADER OFF");
			writeline(obj.visaObj, ":ACQUIRE:MODE SEGM");
			writeline(obj.visaObj, ":ACQ:SEGM:COUN 5");
			writeline(obj.visaObj, ":ACQUIRE:COMPLETE 100");
			writeline(obj.visaObj, ":DISK:SEGMented ALL");
			%writeline(obj.visaObj, strcat(":WAVeform:SOURce CHANNEL", int2str(chan)));

			% BIN file acquisition
			sysLocation = strcat("C:\DataDownload\", folder, "\");

			writeline(obj.visaObj, ":DIGITIZE"); %  CHANNEL", int2str(chan))
			pause(0.5);
			writeline(obj.visaObj, strcat(":DISK:SAVE:WAV ALL, '", sysLocation, file, "', BIN, OFF"));

			% Import the bins
			scopeLocation = strcat("\\192.168.158.14\DataDownload\", folder, "\");
			[timeVector, Excitation] = importAgilentBin(strcat(scopeLocation, file, ".bin"),1);
			[~, KSprobeOut] = importAgilentBin(strcat(scopeLocation, file, ".bin"),2);
			[~, SensorOut] = importAgilentBin(strcat(scopeLocation, file, ".bin"),3);
			data = 1;
		end

%		function acquireMultiRate(obj, )

		function data = acquireContBin(obj, folder, file)
			% BIN file acquisition
			sysLocation = strcat("C:\DataDownload\", folder, "\");

			writeline(obj.visaObj, ":SYSTEM:HEADER OFF");
			writeline(obj.visaObj, ":ACQUIRE:MODE RTIME");
			writeline(obj.visaObj, ":ACQUIRE:COMPLETE 90");
			writeline(obj.visaObj, ":DIGITIZE"); %  CHANNEL", int2str(chan))
			c = 10;
			writeline(obj.visaObj, strcat(":DISK:SAVE:WAV ALL, '", sysLocation, file, num2str(c), "', BIN, OFF"));
			writeline(obj.visaObj, ":DIGITIZE"); %  CHANNEL", int2str(chan))
			c = 11;
			writeline(obj.visaObj, strcat(":DISK:SAVE:WAV ALL, '", sysLocation, file, num2str(c), "', BIN, OFF"));
		end

		function elab = processData(obj, data)
			vect = split(data, ",");
			elab = str2double(vect);
		end

		function offAllChan(obj)
			writeline(obj.visaObj, 'CHAN1:DISP OFF');
			writeline(obj.visaObj, 'CHAN2:DISP OFF');
			writeline(obj.visaObj, 'CHAN3:DISP OFF');
			writeline(obj.visaObj, 'CHAN4:DISP OFF');
		end
	end
end