classdef awg_Agi_81150A_class<handle
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Class for Agilent 33210A Arbitrary Waveform Generator 						%
%																				%
%%% Methods:																	%
%		- init(resource)				// Open device connection 				%
%		- reset()						// Reset to default 					%
%		- rawWrite(comm)				// Write given command on SCPI 			%
%		- data = rawWR(comm)			// Write command and get output 		%
%		- outpSine(freq, ampl)			// Output sine with freq and ampl 		%
%		- setAmplitude(ampl)			// Set AWG output voltage 				%
%		- setWF(wav)					// Set output waveform 					%
%		- setPulse(per, wid, edg)		// Set pulse waveform 					%
%		- setOnOff(state)				// Enable or disable output 			%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

	properties
		visaObj
		opmode
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

			obj.opmode = "SIN";

			res = true;
		end

		function reset(obj)
			% Reset the AWG to initial state

			obj.opmode = "SIN";
			obj.rawWrite("*RST");
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

		function r = idn(obj)
			% Get IDN of instrument
			r = writeread(obj.visaObj, "*IDN?");
		end

		function outpSine(obj, freq, ampl, varargin)
			% Set AWG output to SIN with provided freq and amplitude
			% args:
			%   freq: integer (in Hz)
			%	ampl: float (in V)

			%writeline(obj.visaObj, strcat('APPL:SIN ', freq, ', ', ampl));
			obj.rawWrite("FUNC SIN");
			obj.rawWrite(strcat("FREQ ", num2str(freq)));
			obj.rawWrite(strcat("VOLT ", num2str(ampl)));

			% Optional arguments are voltage offset
			optargs = {0.0};
			if nargin > 3
				optargs(1:(nargin-3)) = varargin;
			end
			v_offs = optargs{:};

			obj.rawWrite(strcat("VOLT:OFFS ", num2str(v_offs)));
			obj.rawWrite("OUTPut ON");
		end

		function setWF(obj, chan, wav)
			% Set AWG output waveform
			% args:
			%   wav: string {'SIN'|'SQU'|'PULS'|'RAMP'|'DC'}
			wav = upper(wav)
			if ismember(wav, ["SQU" "SIN" "PULS" "RAMP" "DC"])
				obj.rawWrite(strcat("FUNC ", wav));
				obj.opmode = wav;
			else
				disp("Wrong waveform");
			end
		end

		function setAmpl(obj, chan, ampl)
			% Set AWG output voltage
			% args:
			%   ampl: integer
			
			if isa(ampl, 'integer') || isa(ampl, 'double')
				ampl = num2str(ampl);
			end

			if obj.opmode == "DC"
				obj.rawWrite(strcat("VOLT:OFFS ", ampl));
			else
				obj.rawWrite(strcat("VOLT ", ampl));
			end
		end

		function setOffs(obj, chan, offs)
			% Set AWG output voltage
			% args:
			%   offs: integer
			
			if isa(offs, 'integer') || isa(offs, 'double')
				offs = num2str(offs);
			end

			obj.rawWrite(strcat(":VOLT", num2str(chan), ":OFFS ", offs));
		end

		function setFreq(obj, chan, freq)
			% Set AWG output frequency
			% args:
			%	chan: integer {1|2}
			%   freq: double
			
			if isa(freq, 'integer') || isa(freq, 'double')
				freq = num2str(freq);
			end

			obj.rawWrite(strcat(":FREQ", num2str(chan), " ", freq));
		end

		function setHIB(obj, chan)
			% Set channel in HI Bandwidth mode (0-240MHz)

			obj.rawWrite(strcat(":OUTP", num2str(chan), ":ROUT HIB"));
		end

		function setHIV(obj, chan)
			% Set channel in HI Voltage mode (0-50MHz)

			obj.rawWrite(strcat(":OUTP", num2str(chan), ":ROUT HIV"));
		end


		function setPulse(obj, per, wid, edg)
			% Set AWG pulse waveform
			% args:
			%   per: integer (period in S) (min 200ns)
			%	wid: integer (pulse width in S)
			%	edg: integer (edge duration in S) (min 20ns)

			% Set min value for edge time if not specified
			if nargin < 4
				edg = 20e-9;
			end

			% Chech min value accepted by awg
			if wid < 40e-9
				wid = 40e-9;
			end
			if per < 200e-9
				per = 200e-9;
			end

			% Ensure to satisfy the requirements
			per_con = wid + 1.6*edg;
			if per < per_cond
				per = per_cond
			end
			edg_con = 0.625*wid;
			if edg > edg_con
				edg = edg_con
			end

			obj.rawWrite(strcat("FUNC:PULS:PER ", num2str(per))); % Set pulse period
			obj.rawWrite(strcat("FUNC:PULS:WIDT ", num2str(wid))); % Set pulse width
			obj.rawWrite(strcat("FUNC:PULS:TRAN ", num2str(edg))); % Set edge transition time
		end

		function setOnOff(obj, chan, state)
			% Set output on/off
			% args:
			%	chan: integer {1|2}
			%	state: {0|1|'ON'|'OFF'}
			
			if isa(state, 'integer') || isa(state, 'double')
				if state == 1
					state = 'ON';
				else
					state = 'OFF';
				end
			end
			if ~ismember(state, ['ON' 'OFF'])
				disp("Wrong parameter")
				return
			else

			if chan < 0
				obj.rawWrite(strcat("OUT", num2str(-chan), ":COMP ", state));
			else
				obj.rawWrite(strcat("OUT", num2str(chan), " ", state));
			end
		end
	end
end