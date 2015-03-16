-- --------------------------------------------------
-- Tacno - UniversRadio (tacnoWorlf (c) for DCS World
-- version 0.00.01
-- Date 2014.09.13
-- Author "Tacno" (c) contact@tacnoworld.fr
-- --------------------------------------------------
-- Export aircraft data for UniversRadio

-- 2013.01.17 : DCS World
-- --------------------------------------------------
-- 0.00.01 : 2014.09.13 : First version
-- 0.00.02 : 2014.12.05 : Ka50
-- 0.00.03 : 2014.12.07 : Correct Ka50 + SPU9 SW
-- 0.00.08 : 2015.02.21 : Volumes

-- For include of socket package
package.path  = package.path..";.\\LuaSocket\\?.lua"
package.cpath = package.cpath..";.\\LuaSocket\\?.dll"
socket = require( "socket");

-- change here to the host an port you want to contact
host =	"localhost";
udpport = 10602;

Memo_FQ = "";
Memo_LLALT = "";
Memo_VOL = "";
Memo_ACTIVE = "";


Aircraft_type = { "F-15C", "A-10A","MiG-29A", "MiG-29G", "MiG-29S", "Su-25", "Su-27","Su-33","A-10C","Ka-50","Mi-8MTV2","UH-1H", "Su-25T","P51-D","TF-51D" }
R828FreqTab =  { "035.650" , "025.675" , "048.550" , "035.650" , "067.775" , "052.825" , "048.250" , "042.050" , "052.750", "023.725" }


sUniversRadio=
{
	UpdateLLAPeriod = 2;
	LLATime  = 0 ;
	UpdateRadio = 0.5;
	RadioTime = 0;
	RefreshRadio = 2;
	RfshRadioTime = 0;

	-- convert host name to ip address
	ip = socket.try(socket.dns.toip(host));
	-- create a new UDP object
	udp = socket.try(socket.udp());


	-- -------------------
	-- S T A R T PROCEDURE
	StartProc=function(self)
	end,

	-- --------------
	-- U P D A T E
	UpdateProc=function(self)
		CurrentTime=LoGetModelTime();


		if CurrentTime >= self.LLATime then --Update LLA
			self.LLATime = CurrentTime + self.UpdateLLAPeriod;

			MyPlane = LoGetSelfData ();
			if ( MyPlane ) then
				--It is an aircraft
				DataToSend = string.format ("SET_LLALT: %3.6f %3.6f %d 100 \0" , MyPlane.LatLongAlt.Lat , MyPlane.LatLongAlt.Long ,  MyPlane.LatLongAlt.Alt*3.2808 );
				--send udp msg to localhost
				self.udp:sendto( DataToSend , self.ip , udpport );
			else
				--It is not an aircraft
				CameraPosition=LoGetCameraPosition()
				CameraPosition3D=CameraPosition.p
				CameraCoordinates=LoLoCoordinatesToGeoCoordinates(CameraPosition3D.x,CameraPosition3D.z)
				DataToSend = string.format ("SET_LLALT: %3.6f %3.6f %d 2 \0" , CameraCoordinates.latitude , CameraCoordinates.longitude , CameraPosition3D.y *3.2808  );
				--send udp msg to localhost
				self.udp:sendto( DataToSend , self.ip , udpport );
			end
		end -- end refresh route to

		if CurrentTime >= self.RfshRadioTime then --RefreshRadio (case of TS restarted)
			self.RfshRadioTime = CurrentTime + self.RefreshRadio;
			self.udp:sendto( Memo_FQ , self.ip , udpport )
			MyPlane = LoGetSelfData ()
			if ( MyPlane ) then
				if ( MyPlane.Name == "Ka-50" ) then
					self.udp:sendto( Memo_ACTIVE , self.ip , udpport )
				end
			end
		end


		if CurrentTime >= self.RefreshRadio then
			self.RadioTime = CurrentTime + self.UpdateRadio
			MyPlane = LoGetSelfData ();
			if ( MyPlane ) then
				-- -----------
				-- A 1 0 C
				if ( MyPlane.Name == "A-10C" ) then
					t = list_cockpit_params ()
					local lDevice = GetDevice(0)

					--FREQUENCIES
					index = string.find ( t , "VHF_AM_FREQ:" )
					AM = string.sub ( t , index +12 , index +12 + 6 )
					index = string.find ( t , "UHF_FREQ:"  )
					UHF = string.sub ( t , index +9, index +9 + 6 )
					index = string.find ( t , "VHF_FM_FREQ:" )
					FM = string.sub ( t , index +12 , index +12 + 5 )

					--CHECK ENERGY
					BATTERY   = lDevice:get_argument_value(246)
					APU_GEN   = lDevice:get_argument_value(241)
					AC_GEN_L  = lDevice:get_argument_value(244)
					AC_GEN_R  = lDevice:get_argument_value(245)
					APU_RPM   = lDevice:get_argument_value(13)
					ENG_L_RPM = lDevice:get_argument_value(78)
					ENG_R_RPM = lDevice:get_argument_value(80)
					UHF_ON	  = lDevice:get_argument_value(168)
					AM_ON	  = lDevice:get_argument_value(138)
					FM_ON	  = lDevice:get_argument_value(152)


					MIN_ENERG = ( BATTERY>0)
					NORMAL_ENERG =  ( (APU_GEN>0) and (APU_RPM>0.75 ) ) or (( AC_GEN_L>0 ) and (ENG_L_RPM>0.5) ) or (( AC_GEN_R>0 ) and (ENG_R_RPM>0.5) )

					if not( MIN_ENERG or NORMAL_ENERG ) then
						UHF = "000.000"
					end
					if not( NORMAL_ENERG ) then
						AM = "000.000"
						FM = "00.000"
					end
					--CHECK RADIO ON
					if ( UHF_ON	< 0.1 )  then UHF = "000.000" end
					if ( AM_ON	< 0.1 ) then AM  = "000.000" end
					if ( FM_ON	< 0.1 ) then FM  =  "00.000" end

					--ENCRYPTION KY58
					ENCRYPT = "000.000"
					CODE = 0

					KY58_ON = math.floor( 0.5 +(lDevice:get_argument_value(784) *10   ) )
					KY58_OP = math.floor( 0.5 +(lDevice:get_argument_value(783) *10   ) )
					KY58_PLAIN =  math.floor( 0.5 +(lDevice:get_argument_value(781) *10   ) )
					KY58_CODE =  math.floor( 0.5 +(lDevice:get_argument_value(782) *10   ) ) +1
					KY58_ZERO =  math.floor( 0.5 +(lDevice:get_argument_value(779) *10   ) )
					 if ( ( KY58_ON + KY58_OP + KY58_ZERO ) == 10 ) then
						if ( KY58_PLAIN == 0 ) then
							ENCRYPT = UHF
							CODE = 1000+KY58_CODE
						end
						if ( KY58_PLAIN == 2 ) then
							ENCRYPT = AM
							CODE = 1000+KY58_CODE
						end
					 end
					DataToSend =  string.format ( "SET_RADIO: 0%s %s %s %s %d \0" , FM, AM , UHF , ENCRYPT , CODE )
					--send udp msg to localhost
					if ( Memo_FQ ~= DataToSend ) then
						self.udp:sendto( DataToSend , self.ip , udpport )
						Memo_FQ = DataToSend
					end
					--VOLUMES
					VOL_FM =  100-math.floor( (lDevice:get_argument_value(147) *100   ) )
					VOL_AM =  100-math.floor( (lDevice:get_argument_value(133) *100   ) )
					VOL_UHF = 100-math.floor( (lDevice:get_argument_value(171) *100   ) )

					DataToSend =  string.format ( "SET_VOLUM: %d %d %d \0" , VOL_FM, VOL_AM , VOL_UHF  )
					if ( Memo_VOL ~= DataToSend ) then
						self.udp:sendto( DataToSend , self.ip , udpport )
						Memo_VOL = DataToSend
					end
				end -- End A10

				-- -----------
				-- K A 5 0
				if ( MyPlane.Name == "Ka-50" ) then
					local lDevice = GetDevice(0)
					--SPU9
					SPU9 = math.floor( 0.5 +(lDevice:get_argument_value(428) *10) )
					ACTIVE = "___"
					if SPU9 == 0 then ACTIVE = "_X_"
						elseif SPU9 == 1 then ACTIVE = "X__"
						elseif SPU9 == 2 then ACTIVE = "__X"
						else ACTIVE = "___"
					end
					DataToSend =  string.format ( "SET_ACTIV: %s \0" , ACTIVE )

					if ( Memo_ACTIVE ~= DataToSend ) then
						self.udp:sendto( DataToSend , self.ip , udpport )
						Memo_ACTIVE = DataToSend
					end

					--VHF1 R828
					local R828 = GetDevice(49)
					local F828 = R828:get_frequency() / 1000
					VHF1 = string.format("%.3f",F828);
					
					--VHF2 R800
					local R800 = GetDevice(48)
					local F800 = R800:get_frequency() / 1000
					VHF2 = string.format("%.3f",F800);
					
					
					EMERGENCY = math.floor( 0.5 +(lDevice:get_argument_value(421) *1) )
					if ( EMERGENCY == 1 ) then
						VHF2 = "121.500"
					end
					--SPU9SW
					SPU9SW = "625.000"

					--CHECK ENERGY
					BATTERY1   = lDevice:get_argument_value(264)
					BATTERY2   = lDevice:get_argument_value(543)
					VHF1_ON    = lDevice:get_argument_value(285)
					VHF2_ON    = lDevice:get_argument_value(286)
					INTERCOM   = lDevice:get_argument_value(284)

					NORMAL_ENERG = ( INTERCOM > 0 ) and ( ( BATTERY1>0 ) or ( BATTERY2>0 ) )

					if not( NORMAL_ENERG ) then
						VHF1 = "000.000"
						VHF2 = "000.000"
						SPU9SW = "000.000"
					end
					--CHECK RADIO ON
					if ( VHF1_ON < 0.1 ) then  VHF1 = "000.000" end
					if ( VHF2_ON < 0.1 ) then  VHF2 = "000.000" end

					DataToSend =  string.format ( "SET_RADIO: %s %s %s 000.000 0 \0" , VHF1, VHF2 , SPU9SW )
					if ( Memo_FQ ~= DataToSend ) then
						self.udp:sendto( DataToSend , self.ip , udpport )
						Memo_FQ = DataToSend
					end
					--VOLUMES
					VOL_VHF1 = math.floor( (lDevice:get_argument_value(372) *100   ) )
					DataToSend =  string.format ( "SET_VOLUM: %d 100 100 \0" , VOL_VHF1 )
					if ( Memo_VOL ~= DataToSend ) then
						self.udp:sendto( DataToSend , self.ip , udpport )
						Memo_VOL = DataToSend
					end
				end --End Ka50
				
				-- ------------------------------------------------------------------------------------------------------------
				-- MI-8
				if ( MyPlane.Name == "Mi-8MT" ) then
					local lDevice = GetDevice(0)
					
					--SPU7 Selecteur d'emission
					local SPU7 = math.floor( 0.5 +(lDevice:get_argument_value(550) *10) )
					local ACTIVE = "___"
					if SPU7 == 0 then ACTIVE = "_X_" -- Position R863 VHF2
						elseif SPU7 == 1 then ACTIVE = "__X" -- Position Jadro HF
						elseif SPU7 == 2 then ACTIVE = "X__" -- Position R828 VHF1
						else ACTIVE = "___"
					end
					DataToSend =  string.format ( "SET_ACTIV: %s \0" , ACTIVE )

					if ( Memo_ACTIVE ~= DataToSend ) then
						self.udp:sendto( DataToSend , self.ip , udpport )
						Memo_ACTIVE = DataToSend
					end
					
					--VHF1 R828
					local R828 = GetDevice(39)
					local F828 = R828:get_frequency() / 1000
					local VHF1 = string.format("%.3f",F828);
					--Debug via SIOC : k.sioc.send(11, F828)	
					
					--VHF2 R863
					local R863 = GetDevice(38)
					local F863 = R863:get_frequency() / 1000
					local VHF2 = string.format("%.3f",F863);
					--Debug via SIOC : k.sioc.send(12, F863)	
					
					--HF Jadro
					local RJad = GetDevice(37)
					local FJad = RJad:get_frequency() / 1000
					local HF = string.format("%.3f",FJad);
					--Debug via SIOC : k.sioc.send(13, FJad)
					
					--CHECK ENERGY
					local BATTERY   = ((lDevice:get_argument_value(495) +  lDevice:get_argument_value(496)) > 0 ) -- Position Switches Bat-1 OU Bat-2
					local EXTPWR = ((lDevice:get_argument_value(502) +  lDevice:get_argument_value(507)) > 1 ) -- Position Switch Ext Power ET Voyant
					local RECT = ((lDevice:get_argument_value(529) + lDevice:get_argument_value(530) + lDevice:get_argument_value(531)) * 100 > 4 )  -- Rectifier load 1 OU 2 OU 3
					
					local R828_ON    = (lDevice:get_argument_value(756) > 0.1)  -- Switch On R-828 sur boitier R828
					local R863_ON    = (lDevice:get_argument_value(627) > 0.1)  -- Switch On R-863 CB overhead panel
					local Jadro   = (lDevice:get_argument_value(484) > 0.1)  -- Switch On Jadro overhead panel Triangulaire Droit
										
					local ENERG_863 =  BATTERY  or  EXTPWRSW -- 1 Batterie ou  ExtPwrSwitch+Voyant 
					local ENERG_828 =  RECT  or EXTPWR -- 1 Rectifier ou  ExtPwrSwitch+Voyant 
					local ENERG_JAD =  RECT  or EXTPWR -- 1 Rectifier ou  ExtPwrSwitch+Voyant 
									

					if not ( ENERG_863 and R863_ON ) then
						VHF2 = "000.000"
					end
					
					if not ( ENERG_828 and R828_ON ) then
						VHF1 = "000.000"
					end
					
					if not ( ENERG_863 and Jadro ) then
						HF = "000.000"
					end
					
					
					DataToSend =  string.format ( "SET_RADIO: %s %s %s 000.000 0 \0" , VHF1, VHF2 , HF )
					if ( Memo_FQ ~= DataToSend ) then
						self.udp:sendto( DataToSend , self.ip , udpport )
						Memo_FQ = DataToSend
					end
					
					
					--VOLUMES
					VOL_VHF2 = math.floor( (lDevice:get_argument_value(156) * 100   ) )
					-- Debug via SIOC : k.sioc.send(10, VOL_VHF2)	
					
					
					DataToSend =  string.format ( "SET_VOLUM: %d 100 100 \0" , VOL_VHF2 )
					if ( Memo_VOL ~= DataToSend ) then
						self.udp:sendto( DataToSend , self.ip , udpport )
						Memo_VOL = DataToSend
					end
				end --End Mi-8
				
				
			end
		end
	end,

	-- -----------------------------
	-- S T O P
	EndProc=function(self)

	end,
}

-- ******************************************************************************************************
-- Works once just before mission start.
do
	local PrevLuaExportStart=LuaExportStart;

	LuaExportStart=function()
		sUniversRadio:StartProc();

		if PrevLuaExportStart then
			PrevLuaExportStart();
		end
	end
end

-- Works just after every simulation frame.
do
	local PrevLuaExportAfterNextFrame=LuaExportAfterNextFrame;

	LuaExportAfterNextFrame=function()
		sUniversRadio:UpdateProc()

		if PrevLuaExportAfterNextFrame then
			PrevLuaExportAfterNextFrame()
		end
	end
end

-- Works once just after mission stop.
do
	local PrevLuaExportStop=LuaExportStop;

	LuaExportStop=function()
		sUniversRadio:EndProc()

		if PrevLuaExportStop then
			PrevLuaExportStop()
		end
	end
end
