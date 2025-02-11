_G._ = require 'lodash'

local scriptPath = ''

package.path = "../?.lua;" .. scriptPath .. '/?.lua;../device-adapters/?.lua;../../../scripts/lua/?.lua;' .. package.path

local testData = require('tstData')

local LOG_INFO = 2
local LOG_DEBUG = 3
local LOG_ERROR = 1

local utils = require('Utils')
local function values(t)
	local values = _.values(t)
	table.sort(values)
	return values
end

local function getDevice_(
	domoticz,
	name,
	state,
	changed,
	type,
	subType,
	rawData,
	additionalRootData,
	additionalDataData,
	hardwareType,
	hardwareTypeValue,
	baseType,
	dummyLogger,
	batteryLevel,
	signalLevel,
	nValue,
	customImage)

	local Device = require('Device')

	if (rawData == nil) then
		rawData = {
			[1] = "1",
			[2] = '2',
			[3] = '3'
		}
	end

	if (additionalRootData == nil) then
		additionalRootData = {}
	end

	if (additionalDataData == nil) then
		additionalDataData = {}
	end

	if (hardwareType == nil) then
		hardwareType = 'ht1'
	end
	if (hardwareTypeValue == nil) then
		hardwareTypeValue = 'ht1'
	end

	local data =
	{
		["id"] = 1,
		["name"] = name,
		["customImage"] = 102,
		["description"] = "Description 1",
		["batteryLevel"] = batteryLevel and batteryLevel or 50,
		["protected"] = true,
		["signalLevel"] = signalLevel and signalLevel or 11,
		["deviceType"] = type and type or "someSubType",
		["deviceID"] = "123abc",
		["subType"] = subType and subType or "someDeviceType",
		["timedOut"] = true,
		["switchType"] = "Contact",
		["switchTypeValue"] = 2,
		["lastUpdate"] = "2016-03-20 12:23:00",
		["data"] = {
		["_state"] = state,
		["hardwareName"] = "hw1",
		["hardwareType"] = hardwareType,
		["hardwareTypeValue"] = hardwareTypeValue,
		["hardwareID"] = 1,
		['protected'] = true,
		['_nValue'] = nValue or 123,
		['unit'] = 1
		},
		["rawData"] = rawData,
		["baseType"] = baseType or "device",
		["changed"] = changed,
		["changedAttribute"] = 'temperature' --tbd
	}

	for attribute, value in pairs(additionalRootData) do
		data[attribute] = value
	end

	for attribute, value in pairs(additionalDataData) do
		data.data[attribute] = value
	end

	return Device(domoticz, data, dummyLogger)
end

local function getDevice(domoticz, options)

	return getDevice_(domoticz,
		options.name,
		options.state,
		options.changed,
		options.type,
		options.subType,
		options.rawData,
		options.additionalRootData,
		options.additionalDataData,
		options.hardwareType,
		options.hardwareTypeValue,
		options.baseType,
		options.dummyLogger,
		options.batteryLevel,
		options.signalLevel,
		options.nValue,
		options.customImage)

end

describe('device', function()
	local Device
	local commandArray = {}
	local cmd
	local device
	local TimedCommand
	local _d
	local domoticz = {
		settings = {
			['Domoticz url'] = 'http://127.0.0.1:8080',
			['Log level'] = 2
		},
		['radixSeparator'] = '.',
		switchGroup = function(group, value)
			return TimedCommand(_d, 'Group:' .. group, value, 'device')
		end,
		setScene = function(scene, value)
			return TimedCommand(_d, 'Scene:' .. scene, value, 'device')
		end,
		sendCommand = function(command, value)
			table.insert(commandArray, {[command] = value})
			return commandArray[#commandArray], command, value
		end,
		openURL = function(url)
			return table.insert(commandArray, url)
		end
	}
	_d = domoticz

	setup(function()
		_G.logLevel = 1
		_G.TESTMODE = true
		_G.globalvariables = {
			Security = 'sec',
			['radix_separator'] = '.',
			['script_reason'] = 'device',
			['script_path'] = scriptPath,
			['domoticz_listening_port'] = '8080',
			['currentTime'] = '2017-08-17 12:13:14.123'
		}

		_G.domoticzData = {}

		TimedCommand = require('TimedCommand')

		Device = require('Device')
	end)

	teardown(function()
		Device = nil
	end)

	before_each(function()
		device = getDevice(domoticz, {
			['name'] = 'myDevice',
			['type'] = 'Light/Switch',
			['state'] = 'On',
			['customImage'] = 102,
			['changed'] = true,
		})
		utils = device._getUtilsInstance()
		utils.print = function() end
	end)

	after_each(function()
		device = nil
		commandArray = {}
	end)

	describe('Adapters', function()

		it('should apply the generic device', function()

			local device = getDevice(domoticz, {
				['name'] = 'myDevice',
				changed = true,
				type = 'sometype',
				subType = 'sub',
				hardwareType = 'hwtype',
				hardwareTypeValue = 'hvalue',
				state = 'bla',
				id = 1,
			})

			assert.is_same(true, device.changed)
			assert.is_same('Description 1', device.description)
			assert.is_same('sometype', device.deviceType)
			assert.is_same('hw1', device.hardwareName)
			assert.is_same('hwtype', device.hardwareType)
			assert.is_same(1, device.hardwareId)
			assert.is_same('hvalue', device.hardwareTypeValue)
			assert.is_same('Contact', device.switchType)
			assert.is_same(2, device.switchTypeValue)
			assert.is_same(true, device.timedOut)
			assert.is_same(true, device.protected)
			assert.is_same(50, device.batteryLevel)
			assert.is_same(11, device.signalLevel)
			assert.is_same('sub', device.deviceSubType)
			assert.is_same(2016, device.lastUpdate.year)
			assert.is_same({'1', '2', '3'}, device.rawData)
			assert.is_same(123, device.nValue)
			assert.is_same('123abc', device.deviceId)
			assert.is_same(1, device.idx)

			assert.is_not_nil(device.setState)
			assert.is_same('bla', device.state)

			assert.is_false(device.isHTTPResponse)
			assert.is_false(device.isVariable)
			assert.is_false(device.isTimer)
			assert.is_false(device.isScene)
			assert.is_true(device.isDevice)
			assert.is_false(device.isGroup)
			assert.is_false(device.isSecurity)
		end)

		it('should have a cancelQueuedCommands method', function()
			local device = getDevice(domoticz, {
				['name'] = 'myDevice',
				changed = true,
				type = 'sometype',
				subType = 'sub',
				hardwareType = 'hwtype',
				hardwareTypeValue = 'hvalue',
				state = 'bla'
			})

			device.cancelQueuedCommands()
			assert.is_same({
				{ ['Cancel'] = { idx = 1, type = 'device' } },
			}, commandArray)
		end)

		it('should deal with percentages', function()

			local device = getDevice(domoticz, {
				['name'] = 'myDevice ()',
				changed = true,
				type = 'sometype',
				subType = 'sub',
				hardwareType = 'hwtype',
				hardwareTypeValue = 'hvalue',
				state = 'bla',
				batteryLevel = 200,
				signalLevel = 200
			})

			assert.is_nil(device.batteryLevel)
			assert.is_nil(device.signalLevel)

			device = getDevice(domoticz, {
				['name'] = 'myDevice',
				changed = true,
				type = 'sometype',
				subType = 'sub',
				hardwareType = 'hwtype',
				hardwareTypeValue = 'hvalue',
				state = 'bla',
				batteryLevel = 31,
				signalLevel = 11
			})

			assert.is_same(31, device.batteryLevel)
			assert.is_same(11, device.signalLevel)

			device = getDevice(domoticz, {
				['name'] = 'myDevice',
				changed = true,
				type = 'sometype',
				subType = 'sub',
				hardwareType = 'hwtype',
				hardwareTypeValue = 'hvalue',
				state = 'bla',
				batteryLevel = -1,
				signalLevel = 100
			})

			assert.is_nil(device.batteryLevel)
			assert.is_nil(device.signalLevel)
		end)

		it('should detect a lux device', function()
			local device = getDevice_(domoticz, 'myDevice', nil, true, 'Lux', 'Lux')
			assert.is_same(1, device.lux)

			device.updateLux(333)
			assert.is_same({ { ["UpdateDevice"] = {
				idx = 1,
				_trigger = true,
				nValue = 0,
				sValue = '333',
			} } }, commandArray)
		end)

		it('should detect a zone heating device', function()
			local rawData = {
				[1] = 1,
				[2] = '12.5',
				[3] = 'Cozy'
			}
			local device = getDevice_(domoticz, 'myDevice', nil, true, 'Heating', 'Zone', rawData)
			assert.is_same(12.5, device.setPoint)
			assert.is_same('Cozy', device.heatingMode)
		end)

		it('should detect a kwh device', function()

			local device = getDevice(domoticz, {
				['name'] = 'myDevice',
				['subType'] = 'kWh',
				['additionalDataData'] = {
					['counterToday'] = '1.234 kWh',
					['usage'] = '654.44 Watt'
				}
			})

			assert.is_same(1234, device.WhToday)
			assert.is_same(1.234, device['counterToday'])
			assert.is_same(654.44, device['usage'])

			device.updateElectricity(220, 1000)
			assert.is_same({ { ["UpdateDevice"] = {
				idx= 1,
				nValue = 0,
				sValue = '220;1000',
				_trigger = true
			} } }, commandArray)
		end)

		it('should detect an electric usage device', function()

			local device = getDevice(domoticz, {
				['name'] = 'myDevice',
				['type']= 'Usage',
				['subType'] = 'Electric',
				['rawData'] = { [1] = 12345 }
			})

			assert.is_same(12345, device.WhActual)
			assert.is_same(12345, device.actualWatt)
			device.updateEnergy(1000)
			assert.is_same({ { ["UpdateDevice"] = {idx=1, nValue=0, sValue="1000", _trigger=true} } }, commandArray)
		end)

		it('should detect a visibility device', function()

			local device = getDevice(domoticz, {
				['name'] = 'myDevice',
				['type'] = 'General',
				['subType'] = 'Visibility',
				['additionalDataData'] = {
					['visibility'] = 33
				}
			})

			assert.is_same(33, device.visibility)
			device.updateVisibility(22)
			assert.is_same({ { ["UpdateDevice"] = {idx=1, nValue=0, sValue="22", _trigger=true} } }, commandArray)
		end)

		it('should detect a p1 smart meter device', function()

			local device = getDevice(domoticz, {
				['name'] = 'myDevice',
				['type'] = 'P1 Smart Meter',
				['subType'] = 'Energy',
				['rawData'] = {
					[1] = "1",
					[2] = "2",
					[3] = "10",
					[4] = "20",
					[5] = "12345",
					[6] = "280"
				},
				['additionalDataData'] = {
					["counterDelivered"] = 0.03,
					["usage"] = "840 Watt",
					["usageDelivered"] = "280 Watt",
					["counterToday"] = "5.6780 kWh",
					["counter"] = "1.003",
					["counterDeliveredToday"] = "5.789 kWh",
				}
			})

			assert.is_same(1, device.usage1)
			assert.is_same(2, device.usage2)
			assert.is_same(10, device.return1)
			assert.is_same(20, device.return2)
			assert.is_same(12345, device.usage)
			assert.is_same(280, device.usageDelivered)
			assert.is_same(5.789, device.counterDeliveredToday)
			assert.is_same(5.6780, device.counterToday)
			assert.is_same(12345, device.WhActual)
			assert.is_same(12345, device.actualWatt)

			device.updateP1(1, 2, 3, 4, 5, 6)
			assert.is_same({ { ["UpdateDevice"] = {idx=1, nValue=0, sValue="1;2;3;4;5;6", _trigger=true} } }, commandArray)
		end)

		it('should detect a thermostat setpoint device', function()

			local device = getDevice(domoticz, {
				['name'] = 'myDevice',
				['type'] = 'Thermostat',
				['hardwareTypeValue'] = 15,
				['subType'] = 'SetPoint',
				['rawData'] = { [1] = 12.5 }
			})

			assert.is_same(12.5, device.setPoint)

			device.updateSetPoint(14)
			assert.is_same( { { ["UpdateDevice"] = { idx=1, nValue=0, sValue="14", _trigger=true } } }, commandArray)

		end)

		it('should detect a text device', function()

			local device = getDevice(domoticz, {
				['name'] = 'myDevice',
				['type'] = 'Thermostat',
				['subType'] = 'Text',
				['rawData'] = { [1] = 'dzVents rocks' }
			})

			assert.is_same('dzVents rocks', device.text)
			device.updateText('foo')
			assert.is_same({ { ["UpdateDevice"] = {idx=1, nValue=0, sValue="foo", _trigger=true} } }, commandArray)
		end)

		it('should detect a rain device', function()

			local device = getDevice(domoticz, {
				['name'] = 'myDevice',
				['type'] = 'Rain',
			})

			device.updateRain(10, 20)
			assert.is_same({ { ["UpdateDevice"] = {idx=1, nValue=0, sValue="10;20", _trigger=true} } }, commandArray)
		end)

		it('should detect a 2-phase ampere device', function()

			local device = getDevice(domoticz, {
				['name'] = 'myDevice',
				['type'] = 'General',
				['subType'] = 'Current',
				['additionalDataData'] = {
					["current"] = 123,
				}
			})

			assert.is_same(123, device.current)
			device.updateCurrent(10)
			assert.is_same({ { ["UpdateDevice"] = {idx=1, nValue=0, sValue="10", _trigger=true} } }, commandArray)
		end)

		it('should detect a 3-phase ampere device', function()

			local device = getDevice(domoticz, {
				['name'] = 'myDevice',
				['type'] = 'Current',
				['subType'] = 'CM113, Electrisave',
				['rawData'] = {
					[1] = 123,
					[2] = 456,
					[3] = 789,
				}
			})

			assert.is_same(123, device.current1)
			assert.is_same(456, device.current2)
			assert.is_same(789, device.current3)
			device.updateCurrent(10, 20, 30)
			assert.is_same({ { ["UpdateDevice"] = {idx=1, nValue=0, sValue="10;20;30", _trigger=true} } }, commandArray)
		end)

		it('should detect an air quality device', function()

			local device = getDevice(domoticz, {
				['name'] = 'myDevice',
				['type'] = 'Air Quality',
				['additionalDataData'] = {
					['_nValue'] = 12
				}
			})

			assert.is_same(12, device.co2)

			device.updateAirQuality(44)
			assert.is_same({ { ["UpdateDevice"] = {idx=1, nValue=44, sValue="0", _trigger=true} } }, commandArray)
		end)

		it('should detect a security device', function()
			local device = getDevice(domoticz, {
				['name'] = 'myDevice',
				['type'] = 'Security',
				['subType'] = 'Security Panel'
			})

			device.disarm().afterSec(2)
			assert.is_same({ { ['myDevice'] = 'Disarm AFTER 2 SECONDS' } }, commandArray)
			commandArray = {}
			device.armAway().afterSec(3)
			assert.is_same({ { ['myDevice'] = 'Arm Away AFTER 3 SECONDS' } }, commandArray)
			commandArray = {}
			device.armHome().afterSec(4)
			assert.is_same({ { ['myDevice'] = 'Arm Home AFTER 4 SECONDS' } }, commandArray)
		end)

		describe('dummy methods', function()

			it('should set dummy methods', function()

				local dummies = {}

				local device = getDevice(domoticz, {
					['name'] = 'myDevice',
					['type'] = 'some crazy type',
					['subType'] = 'some crazy subtype',
					['hardwareType'] = 'some crazy hardware type',
					['dummyLogger' ] = function(device, name)
						table.insert(dummies, name)
					end
				})

				local adapterManager = device.getAdapterManager()

				assert.is_same({
					"activate",
					"armAway",
					"armHome",
					"close",
					'decreaseBrightness',
					"dimTo",
					"disarm",
					"getColor",
					'increaseBrightness',
					'incrementCounter',
					"kodiExecuteAddOn",
					"kodiPause",
					"kodiPlay",
					"kodiPlayFavorites",
					"kodiPlayPlaylist",
					"kodiSetVolume",
					"kodiStop",
					"kodiSwitchOff",
					'onkyoEISCPCommand',
					"open",
					"pause",
					"play",
					"playFavorites",
					"quietOff",
					"quietOn",
					"reset",
					"setColor",
					"setColorBrightness",
					"setDiscoMode",
					"setHex",
					"setHotWater",
					"setHue",
					"setKelvin",
					"setLevel",
					"setMode",
					'setNightMode',
					'setRGB',
					"setVolume",
					"setWhiteMode",
					"startPlaylist",
					"stop",
					"switchOff",
					"switchOn",
					"switchSelector",
					"toggleSwitch",
					"updateAirQuality",
					"updateAlertSensor",
					"updateBarometer",
					"updateCounter",
					"updateCustomSensor",
					"updateDistance",
					"updateElectricity",
					"updateGas",
					"updateHistory",
					"updateHumidity",
					"updateLux",
					"updateMode",
					"updateP1",
					"updatePercentage",
					"updatePressure",
					"updateRadiation",
					"updateRain",
					"updateSetPoint",
					"updateSoilMoisture",
					"updateSoundLevel",
					"updateTempBaro",
					"updateTempHum",
					"updateTempHumBaro",
					"updateTemperature",
					"updateText",
					"updateUV",
					"updateVisibility",
					"updateVoltage",
					"updateWaterflow",
					"updateWeight",
					"updateWetness",
					"updateWind",
					"updateYouless",
					"volumeDown",
					"volumeUp",
				}, values(dummies))
			end)
		end)

		it('should have generic methods', function()

			local device = getDevice(domoticz, {
				['name'] = 'myDevice',
				['type'] = 'Any',
			})

			assert.is_function(device.protectionOff)
			assert.is_function(device.protectionOn)
			assert.is_function(device.setDescription)
			assert.is_function(device.setIcon)
			assert.is_function(device.setValues)
			assert.is_function(device.rename)

		end)

		it('should handle generic method protectionOff ', function()

			local device = getDevice(domoticz, {
				['name'] = 'myDevice',
				['type'] = 'Any',
			})

			local res;

			domoticz.openURL = function(url)
				res = url;
			end

			device.protectionOff()
			assert.is_same('http://127.0.0.1:8080/json.htm?type=setused&used=true&protected=false&idx=1', res)
		end)

		it('should handle generic method protectionOn ', function()

			local device = getDevice(domoticz, {
				['name'] = 'myDevice',
				['type'] = 'Any',
			})

			local res;
			domoticz.openURL = function(url)
				res = url;
			end

			device.protectionOff()
			assert.is_same('http://127.0.0.1:8080/json.htm?type=setused&used=true&protected=false&idx=1', res)
		end)

		it('should handle generic method setDescription ', function()

			local device = getDevice(domoticz, {
				['name'] = 'myDevice',
				['type'] = 'Any',
			})

			local res;

			domoticz.openURL = function(url)
				res = url;
			end

			device.setDescription('This is a wonderful description of the subject. Thanks !')
			assert.is_same('http://127.0.0.1:8080/json.htm?description=This+is+a+wonderful+description+of+the+subject.+Thanks+%21&idx=1&name=myDevice&type=setused&used=true', res)
		end)

		it('should handle generic method setIcon', function()

			local device = getDevice(domoticz, {
				['name'] = 'myDevice',
				['type'] = 'Any',
			})

			local res;

			domoticz.openURL = function(url)
				res = url;
			end

			device.setIcon(24)
			assert.is_same('http://127.0.0.1:8080/json.htm?type=setused&used=true&name=myDevice&description=Description+1&idx=1&switchtype=2&customimage=24', res)
		end)

		it('should handle generic method rename ', function()

			local device = getDevice(domoticz, {
				['name'] = 'myDevice',
				['type'] = 'Any',
			})

			local res;

			domoticz.openURL = function(url)
				res = url;
			end

			device.rename('who am I')
			assert.is_same('http://127.0.0.1:8080/json.htm?type=command&param=renamedevice&idx=1&name=who+am+I', res)
		end)

		it('should handle generic method setValues', function()

			local device = getDevice(domoticz, {
				['name'] = 'myDevice',
				['type'] = 'Any',
			})

			local res;

			domoticz.openURL = function(url)
				res = url;
			end
			local test = 'sValue'
			device.setValues(12,test,13,14,test)
			assert.is_same('http://127.0.0.1:8080/json.htm?type=command&param=udevice&idx=1&nvalue=12&svalue=sValue;13;14;sValue&parsetrigger=false', res)
		end)

		it('should detect an evohome device', function()

			local device = getDevice(domoticz, {
				['name'] = 'myDevice',
				['type'] = 'Thermostat',
				['subType'] = 'Zone',
				['hardwareTypeValue'] = 39,
				['rawData'] = { [1] = 12.5;
								[3] = "TemporaryOverride";
								[4] = "2016-05-29T06:32:58Z" }
			})

			assert.is_same(12.5, device.setPoint)
			assert.is_same('TemporaryOverride', device.mode)
			assert.is_same('2016-05-29T06:32:58Z', device.untilDate)

			device.updateSetPoint(14, 'Permanent', '2016-04-29T06:32:58Z')

			assert.is_same({ { ['SetSetPoint:1'] = '14#Permanent#2016-04-29T06:32:58Z'} }, commandArray)
		end)

		it('should detect an evohome hotWater device', function()

			local device = getDevice(domoticz, {
				['name'] = 'myDevice',
				['type'] = 'Thermostat',
				['subType'] = 'Hot Water',
				['hardwareTypeValue'] = 39,
				['rawData'] = {
								[2] = "On";
								[3] = "TemporaryOverride";
								[4] = "2016-04-29T06:32:58Z" }
								})

			local res;

			domoticz.openURL = function(url)
				res = url;
			end

			assert.is_same('On', device.state)
			assert.is_same('TemporaryOverride', device.mode)
			assert.is_same('2016-04-29T06:32:58Z', device.untilDate)

			device.setHotWater('Off', 'Permanent')

			assert.is_same('http://127.0.0.1:8080/json.htm?type=setused&idx=1&setpoint=&state=Off&mode=Permanent&used=true', res)
		end)

		it('should detect an evohome Heating device', function()

			local device = getDevice(domoticz, {
				['name'] = 'myDevice',
				['type'] = 'Heating',
				['subType'] = 'Evohome',
				['hardwareTypeValue'] = 39,
				['rawData'] = { [2] = "On";
								[3] = "TemporaryOverride";
								[4] = "2016-04-29T06:32:58Z" }
				})

			local res;

			domoticz.openURL = function(url)
				res = url;
			end

			assert.is_same('On', device.state)
			assert.is_same('TemporaryOverride', device.mode)
			assert.is_same('2016-04-29T06:32:58Z', device.untilDate)

			device.setMode('Busted')

			assert.is_same('http://127.0.0.1:8080/json.htm?type=command&param=switchmodal&idx=1&status=Busted&action=1&ooc=0', res)
		end)

		it('should detect an opentherm gateway device', function()

			local device = getDevice(domoticz, {
				['name'] = 'myDevice',
				['type'] = 'Thermostat',
				['hardwareTypeValue'] = 20,
				['subType'] = 'SetPoint',
				['rawData'] = { [1] = 12.5 }
			})

			local res;

			domoticz.openURL = function(url)
				res = url;
			end

			assert.is_same(12.5, device.setPoint)

			device.updateSetPoint(14)

			assert.is_same('http://127.0.0.1:8080/json.htm?param=udevice&type=command&idx=1&nvalue=0&svalue=14', res)
		end)

		it('should detect a Z-Wave Thermostat mode device', function()

			local device = getDevice(domoticz, {
				['name'] = 'myDevice',
				['subType'] = 'Thermostat Mode',
				['additionalDataData'] = {
					["modes"] = "0;Off;1;Heat;2;Heat Econ;",
					["mode"] = 2;
				}
			})

			assert.is_same({'Off', 'Heat', 'Heat Econ'}, device.modes)
			assert.is_same(2, device.mode)
			assert.is_same('Heat Econ', device.modeString)

			device.updateMode('Heat')
			assert.is_same({ { ["UpdateDevice"] ={idx=1, nValue=1, sValue="Heat", _trigger=true} } }, commandArray)
			commandArray = {}
			device.updateMode('Off')
			assert.is_same({ { ["UpdateDevice"] = {idx=1, nValue=0, sValue="Off", _trigger=true} } }, commandArray)
			commandArray = {}
			device.updateMode('Heat Econ')
			assert.is_same({ { ["UpdateDevice"] = {idx=1, nValue=2, sValue="Heat Econ", _trigger=true} } }, commandArray)

		end)

		it('should detect a Thermostat type 3 device', function()

			local device = getDevice(domoticz, {
				['name'] = 'myDevice',
				['type'] = 'Thermostat 3',
				['subType'] = 'Mertik some type',
				['nValue'] = 2;
				['_nValue'] = 2;
				}
			)

			domoticz.openURL = function(url)
				return url;
			end

			assert.is_same( { 'Off', 'On', 'Up', 'Down', 'Run Up', 'Run Down', 'Stop' } , utils.stringSplit(device.modes,',') )
			assert.is_same(2, device.mode)
			assert.is_same('Up', device.modeString)

			assert.is_same( 'http://127.0.0.1:8080/json.htm?type=command&param=switchlight&idx=1&switchcmd=Off', device.updateMode('Off'))
			assert.is_same( 'http://127.0.0.1:8080/json.htm?type=command&param=switchlight&idx=1&switchcmd=On', device.updateMode('On'))
			assert.is_same( 'http://127.0.0.1:8080/json.htm?type=command&param=switchlight&idx=1&switchcmd=Up', device.updateMode('Up'))
			assert.is_same( 'http://127.0.0.1:8080/json.htm?type=command&param=switchlight&idx=1&switchcmd=Down', device.updateMode('Down'))
			assert.is_same( 'http://127.0.0.1:8080/json.htm?type=command&param=switchlight&idx=1&switchcmd=Run%20Up', device.updateMode('Run Up'))
			assert.is_same( 'http://127.0.0.1:8080/json.htm?type=command&param=switchlight&idx=1&switchcmd=Run%20Down', device.updateMode('Run Down'))
			assert.is_same( 'http://127.0.0.1:8080/json.htm?type=command&param=switchlight&idx=1&switchcmd=Stop', device.updateMode('Stop'))
		end)

		it('should detect a wind device', function()
			local device = getDevice(domoticz, {
				['name'] = 'myDevice',
				['type'] = 'Wind',
				['rawData'] = {
					[1] = "243";
					[2] = "SE";
					[3] = "660";
					[4] = "120";
					[5] = "33";
					[6] = "32";
				}
			})
			assert.is.same(12, device.gust)
			assert.is.same(12, device.gustMs)
			assert.is.same(66, device.speedMs)
			assert.is.same(33, device.temperature)
			assert.is.same(32, device.chill)

			device.updateWind(1, 2, 3, 4, 5, 6)
			assert.is_same({ { ["UpdateDevice"] = {idx=1, nValue=0, sValue="1;2;30;40;5;6", _trigger=true} } }, commandArray)
		end)

		it('should detect a uv device', function()
			local device = getDevice(domoticz, {
				['name'] = 'myDevice',
				['type'] = 'UV',
				['rawData'] = {
					[1] = "123.55";
					[2] = "0";
				}
			})
			assert.is.same(123.55, device.uv)

			device.updateUV(33.5)
			assert.is_same({ { ["UpdateDevice"] = {idx=1, nValue=0, sValue="33.5;0", _trigger=true} } }, commandArray)
		end)

		it('should detect a barometer device', function()
			local device = getDevice(domoticz, {
				['name'] = 'myDevice',
				['subType'] = 'Barometer',
			})

			device.updateBarometer(1024, 'thunderstorm')
			assert.is_same({ { ["UpdateDevice"] = {idx=1, nValue=0, sValue="1024;4", _trigger=true} } }, commandArray)
		end)

		it('should detect a temperature device', function()
			local device = getDevice(domoticz, {
				['name'] = 'myDevice',
				['type'] = 'Temp',
			})

			device.updateTemperature(23)
			assert.is_same({ { ["UpdateDevice"] = {idx=1, nValue=0, sValue="23", _trigger=true} } }, commandArray)
		end)

		it('should detect a humidity device', function()
			local device = getDevice(domoticz, {
				['name'] = 'myDevice',
				['type'] = 'Humidity',
				['additionalDataData'] = {
					["humidityStatus"] = "Wet";
				}
			})

			device.updateHumidity(66, 'wet')
			assert.is_same({ { ["UpdateDevice"] = {idx=1, nValue=66, sValue="wet", _trigger=true} } }, commandArray)
			assert.is_same(3, device.humidityStatusValue)
		end)

		it('should detect a temp+humidity device', function()
			local device = getDevice(domoticz, {
				['name'] = 'myDevice',
				['type'] = 'Temp + Humidity',
				['additionalDataData'] = {
					["humidityStatus"] = "Dry";
				}
			})

			device.updateTempHum(10, 12, 'wet')
			assert.is_same({ { ["UpdateDevice"] = {idx=1, nValue=0, sValue="10;12;wet", _trigger=true} } }, commandArray)
			assert.is_same(2, device.humidityStatusValue)

			commandArray = {}
			device.updateTempHum(10, 12)
			assert.is_same({ { ["UpdateDevice"] = {idx=1, nValue=0, sValue="10;12;2", _trigger=true} } }, commandArray)
			assert.is_same(2, device.humidityStatusValue)

			commandArray = {}
			device.updateTempHum(24, 52)
			assert.is_same({ { ["UpdateDevice"] = {idx=1, nValue=0, sValue="24;52;1", _trigger=true} } }, commandArray)
			assert.is_same(2, device.humidityStatusValue)
		end)

		it('should detect a temp+humidity+barometer device', function()
			local device = getDevice(domoticz, {
				['name'] = 'myDevice',
				['type'] = 'Temp + Humidity + Baro',
				['additionalDataData'] = {
					["humidityStatus"] = "Comfortable";
				}
			})

			device.updateTempHumBaro(10, 12, 2, 1000, 'rain')
			assert.is_same({ { ["UpdateDevice"] = {idx=1, nValue=0, sValue="10;12;2;1000;4", _trigger=true} } }, commandArray)
			assert.is_same(1, device.humidityStatusValue)

			commandArray = {}
			device.updateTempHumBaro(10, 12, -1, 1000, 'rain')
			assert.is_same({ { ["UpdateDevice"] = {idx=1, nValue=0, sValue="10;12;2;1000;4", _trigger=true} } }, commandArray)
			assert.is_same(1, device.humidityStatusValue)

			commandArray = {}
			device.updateTempHumBaro(24, 52, -1, 1000, 'rain')
			assert.is_same({ { ["UpdateDevice"] = {idx=1, nValue=0, sValue="24;52;1;1000;4", _trigger=true} } }, commandArray)
			assert.is_same(1, device.humidityStatusValue)
		end)

		it('should detect a temp+barometer device', function()
			local device = getDevice(domoticz, {
				['name'] = 'myDevice',
				['type'] = 'Temp + Baro'
			})

			device.updateTempBaro(10, 1000, 'thunderstorm')
			assert.is_same({ { ["UpdateDevice"] = {idx=1, nValue=0, sValue="10;1000;4", _trigger=true} } }, commandArray)
		end)

		it('should detect a counter device', function()
			local device = getDevice(domoticz, {
				['name'] = 'myDevice',
				['subType'] = 'RFXMeter counter',
				['additionalDataData'] = {
					["counterToday"] = "123.44 Watt";
					["counter"] = "6.7894 kWh";
				}
			})
			assert.is_same(123.44, device.counterToday)
			assert.is_same(6.7894, device.counter)

			device.updateCounter(555)
			assert.is_same({ { ["UpdateDevice"] = {idx=1, nValue=0, sValue="555", _trigger=true} } }, commandArray)
		end)

		it('should detect an incremental counter device', function()
			local device = getDevice(domoticz, {
				['name'] = 'myDevice',
				['subType'] = 'Counter Incremental',
				['additionalDataData'] = {
					["counterToday"] = "123.44 Watt";
					["counter"] = "6.7894 kWh";
				}
			})
			assert.is_same(123.44, device.counterToday)
			assert.is_same(6.7894, device.counter)

			device.updateCounter(555)
			assert.is_same({ { ["UpdateDevice"] = {idx=1, nValue=0, sValue="555", _trigger=true} } }, commandArray)

			commandArray = {}
			device.incrementCounter(10)
			assert.is_same({ { ["UpdateDevice"] = {idx=1, nValue=0, sValue="10", _trigger=true} } }, commandArray)
		end)

		it('should detect a managed counter device', function()
			local device = getDevice(domoticz, {
				['name'] = 'myDevice',
				['type'] = 'Counter',
				['subType'] = 'Managed Counter',
				['additionalDataData'] = {
					["counterToday"] = "123.44 Watt";
					["counter"] = "6.7894 kWh";
				}
			})

			domoticz.openURL = function(url)
				return table.insert(commandArray, url)
			end

			assert.is_same(123.44, device.counterToday)
			assert.is_same(6.7894, device.counter)

			commandArray = {}
			device.updateCounter(555.123)
			assert.is_same({ { ["UpdateDevice"] = {idx=1, nValue=0, sValue="555.123", _trigger=true} } }, commandArray)

			 commandArray = {}
			device.updateHistory('2021-13-32','12;234567')
			assert.is_same( { 'http://127.0.0.1:8080/json.htm?type=command&param=udevice&idx=1&nvalue=0&svalue=12;234567;2021-13-32' }, commandArray)

			commandArray = {}
			device.updateHistory('2021-13-32 12:34:56','12;234567')
			assert.is_same( { 'http://127.0.0.1:8080/json.htm?type=command&param=udevice&idx=1&nvalue=0&svalue=12;234567;2021-13-32+12%3A34%3A56' }, commandArray)
		end)

		it('should detect a pressure device', function()
			local device = getDevice(domoticz, {
				['name'] = 'myDevice',
				['subType'] = 'Pressure'
			})

			device.updatePressure(567)
			assert.is_same({ { ["UpdateDevice"] = {idx=1, nValue=0, sValue="567", _trigger=true} } }, commandArray)
		end)

		it('should detect a gas device', function()
			local device = getDevice(domoticz, {
				['name'] = 'myDevice',
				['subType'] = 'Gas',
				['additionalDataData'] = {
					["counterToday"] = "5.421 m3";
					["counter"] = "123.445";
				}
			})

			assert.is_same(5.421, device.counterToday)
			assert.is_same(123.445, device.counter)

			device.updateGas(567)
			assert.is_same({ { ["UpdateDevice"] = {idx=1, nValue=0, sValue="567", _trigger=true} } }, commandArray)
		end)

		it('should detect a percentage device', function()
			local device = getDevice(domoticz, {
				['name'] = 'myDevice',
				['subType'] = 'Percentage',
				['rawData'] = { [1] = 99.98 }
			})

			assert.is_same( 99.98, device.percentage )
			device.updatePercentage(12.55)
			assert.is_same({ { ["UpdateDevice"] = {idx=1, nValue=0, sValue="12.55", _trigger=true} } }, commandArray)
		end)

		it('should detect a voltage device', function()
			local device = getDevice(domoticz, {
				['name'] = 'myDevice',
				['subType'] = 'Voltage',
				['additionalDataData'] = { ['voltage'] = 230.12 }
			})

			device.updateVoltage(123.55)
			assert.is_same({ { ["UpdateDevice"] = {idx=1, nValue=0, sValue="123.55", _trigger=true} } }, commandArray)
		end)

		it('should detect an alert device', function()
			local device = getDevice(domoticz, {
				['name'] = 'myDevice',
				['subType'] = 'Alert',
				['rawData'] = { [1] = 'some text' },
				['additionalDataData'] = { ['_nValue'] = 4 }
			})

			assert.is_same(4, device.color)
			assert.is_same('some text', device.text)
			device.updateAlertSensor(0, 'Oh dear!')
			assert.is_same({ { ["UpdateDevice"] = {idx=1, nValue=0, sValue="Oh dear!", _trigger=true} } }, commandArray)
		end)

		it('should detect a distance device', function()
			local device = getDevice(domoticz, {
				['name'] = 'myDevice',
				['subType'] = 'Distance',
				['rawData'] = { [1]="44.33" }
			})

			assert.is_same(44.33, device.distance)

			device.updateDistance(3.14)
			assert.is_same({ { ["UpdateDevice"] = {idx=1, nValue=0, sValue="3.14", _trigger=true} } }, commandArray)
		end)

		it('should detect a custom sensor device', function()
			local device = getDevice(domoticz, {
				['name'] = 'myDevice',
				['subType'] = 'Custom Sensor',
				['rawData'] = { [1]="12" }
			})

			device.updateCustomSensor(12)
			assert.is_same({ { ["UpdateDevice"] = {idx=1, nValue=0, sValue="12", _trigger=true} } }, commandArray)

			assert.is_same(12, device.sensorValue)
			assert.is_same('number' , type(device.sensorValue) )

			local device = getDevice(domoticz, {
				['name'] = 'myDevice',
				['subType'] = 'Custom Sensor',
				['rawData'] = { [1]="12a" }
			})

			assert.is_same('12a', device.sensorValue)
			assert.is_same('string', type(device.sensorValue))

		end)

		it('should detect a solar radiation device', function()
			local device = getDevice(domoticz, {
				['name'] = 'myDevice',
				['subType'] = 'Solar Radiation'
			})

			device.updateRadiation(12)
			assert.is_same({ { ["UpdateDevice"] = {idx=1, nValue=0, sValue="12", _trigger=true} } }, commandArray)
		end)

		it('should detect a leaf wetness device', function()
			local device = getDevice(domoticz, {
				['name'] = 'myDevice',
				['subType'] = 'Leaf Wetness',
				['additionalDataData'] = { ['_nValue'] = 4 }
			})

			assert.is_same(4, device.wetness)
			device.updateWetness(12)
			assert.is_same({ { ["UpdateDevice"] = {idx=1, nValue=12, _trigger=true} } }, commandArray)
		end)

		it('should detect a scale weight device', function()
			local device = getDevice(domoticz, {
				['name'] = 'myDevice',
				['type'] = 'Weight',
				['rawData'] = { [1] = "44" }
			})

			assert.is_same(44, device.weight)
			device.updateWeight(12)
			assert.is_same({ { ["UpdateDevice"] = {idx=1, nValue=0, sValue="12", _trigger=true} } }, commandArray)
		end)

		it('should detect a sound level device', function()
			local device = getDevice(domoticz, {
				['name'] = 'myDevice',
				['subType'] = 'Sound Level',
				['state'] = '120'
			})

			assert.is_same(120, device.level)
			device.updateSoundLevel(33)
			assert.is_same({ { ["UpdateDevice"] = {idx=1, nValue=0, sValue="33", _trigger=true} } }, commandArray)
		end)

		it('should detect a waterflow device', function()
			local device = getDevice(domoticz, {
				['name'] = 'myDevice',
				['subType'] = 'Waterflow',
				['rawData'] = { [1] = "44" }
			})

			assert.is_same(44, device.flow)
			device.updateWaterflow(33)
			assert.is_same({ { ["UpdateDevice"] = {idx=1, nValue=0, sValue="33", _trigger=true} } }, commandArray)
		end)

		it('should detect a soil moisture device', function()
			local device = getDevice(domoticz, {
				['name'] = 'myDevice',
				['subType'] = 'Soil Moisture',
				['additionalDataData'] = { ['_nValue'] = 34 }
			})

			assert.is_same(34, device.moisture)
			device.updateSoilMoisture(12)
			assert.is_same({ { ["UpdateDevice"] = {idx=1, nValue=12, sValue="0", _trigger=true} } }, commandArray)
		end)

		it('should detect a Logitech Media Server device', function()
			local device = getDevice(domoticz, {
				['name'] = 'myDevice',
				['hardwareType'] = 'Logitech Media Server',
				['additionalDataData'] = { ['levelVal'] = 34 }
			})

			device.switchOff()
			device.stop()
			device.play()
			device.pause()
			device.setVolume(10)
			device.startPlaylist('myList')
			device.playFavorites('30')
			assert.is_same(34, device.playlistID)
			assert.is_same({
				{ ["myDevice"] = "Off" },
				{ ["myDevice"] = "Stop" },
				{ ["myDevice"] = "Play" },
				{ ["myDevice"] = "Pause" },
				{ ["myDevice"] = "Set Volume 10" },
				{ ["myDevice"] = "Play Playlist myList TRIGGER" },
				{ ["myDevice"] = "Play Favorites 30 TRIGGER" },
			}, commandArray)
		end)

		it('hould detect a onky device', function()
			commandArray = {}

			domoticz.openURL = function(url)
				return table.insert(commandArray, url)
			end

			local device = getDevice(domoticz, {
				['name'] = 'myDevice',
				['hardwareType'] = 'Onkyo AV Receiver (LAN)',
			})
			device.onkyoEISCPCommand('mycommand')
			assert.is_same({{['CustomCommand:1'] = 'mycommand'}}, commandArray)
		end)

		describe('Switch', function()

			local switch
			local commandArray = {}
			local domoticz = {
				settings = {
					['Domoticz url'] = 'http://127.0.0.1:8080',
					['Log level'] = 2
				},
				['radixSeparator'] = '.',
				sendCommand = function(command, value)
					table.insert(commandArray, { [command] = value })
					return commandArray[#commandArray], command, value
				end
			}

			before_each(function()
				switch = getDevice(domoticz, {
					['type'] = 'Light/Switch',
					['name'] = 's1',
					['state'] = 'On',
				})
			end)

			after_each(function()
				switch = nil
				commandArray = {}
			end)

			it('should toggle the switch', function()
				switch.toggleSwitch()
				assert.is_same({ { ["s1"] = "Off" } }, commandArray)
			end)

			it('should switch on', function()
				switch.switchOn()
				assert.is_same({ { ["s1"] = "On" } }, commandArray)
			end)

			it('should switch off', function()
				switch.switchOff()
				assert.is_same({ { ["s1"] = "Off" } }, commandArray)
			end)

			it('should open', function()
				switch.open()
				assert.is_same({ { ["s1"] = "Open" } }, commandArray)
			end)

			it('should open Blinds', function()
				switch.switchType = "Blinds"
				switch.open()
				assert.is_same({ { ["s1"] = "Open" } }, commandArray)
			end)

			it('should close"Venetian Blinds EU', function()
				switch.switchType = "Venetian Blinds EU"
				switch.close()
				assert.is_same({ { ["s1"] = "Close" } }, commandArray)
			end)

			it('should close', function()
				switch.close()
				assert.is_same({ { ["s1"] = "Close" } }, commandArray)
			end)

			it('should stop', function()
				switch.stop()
				assert.is_same({ { ["s1"] = "Stop" } }, commandArray)
			end)

			it('should dim', function()
				switch.dimTo(50)
				assert.is_same({ { ["s1"] = "Set Level 50" } }, commandArray)
			end)

			it('should setLevel', function()
				switch.setLevel(51)
				assert.is_same({ { ["s1"] = "Set Level 51" } }, commandArray)
			end)

			it('should switch a smoke_detector', function()
				local device = getDevice(domoticz, {
					['type'] = 'Light/Switch',
					['state'] = 'Off',
					['name'] = 'mySmokeDetector',
					['additionalRootData'] = { ['switchType'] = 'Smoke Detector'},
				})
				assert.is_false(device.active)
				device.activate()
				assert.is_same({ {["mySmokeDetector"] = "On"}}, commandArray)

				local device = getDevice(domoticz, {
					['type'] = 'Light/Switch',
					['state'] = 'On',
					['name'] = 'mySmokeDetector',
					['additionalRootData'] = { ['switchType'] = 'Smoke Detector'},
				})

				assert.is_true(device.active)
				local commandArray = {}

				domoticz.openURL = function(url)
					return table.insert(commandArray, url)
				end

				device.reset()
				assert.is_same({ 'http://127.0.0.1:8080/json.htm?type=command&param=resetsecuritystatus&idx=1&switchcmd=Normal' }, commandArray)
			end)

			it('should switch a selector with numeric level', function()
				local switch = getDevice(domoticz, {
					['type'] = 'Light/Switch',
					['name'] = 's1',
					['additionalRootData'] = { ['switchType'] = 'Selector'},
					['additionalDataData'] =
					{ levelNames = "Off|bb|cc|dd|ee|ff|gg|hh|ii|jj|kk|ll|mm|nn|oo|pp|qq|rr|ss|tt" },
				})

				commandArray = {} ;switch.switchSelector(0)
					assert.is_same({ {["s1"]="Set Level 0"}}, commandArray)
				commandArray = {} ;switch.switchSelector(20)
					assert.is_same({ {["s1"]="Set Level 20"}}, commandArray)
				commandArray = {} ;switch.switchSelector(112)
					assert.is_same({ {["s1"]="Set Level 110"}}, commandArray)
				commandArray = {} ;switch.switchSelector(500)
					assert.is_same({ {["s1"]="Set Level 190"}}, commandArray)
				commandArray = {} ;switch.switchSelector(-10.5)
					assert.is_same({ {["s1"]="Set Level 0"}}, commandArray)

			end)

			it('should switch a selector with levelname', function()
				local switch = getDevice(domoticz, {
					['type'] = 'Light/Switch',
					['name'] = 's1',
					['additionalRootData'] = { ['switchType'] = 'Selector'},
					['additionalDataData'] =
					{ levelNames = "Off|bb|cc|dd|ee|ff|gg|hh|ii|jj|kk|ll|mm|nn|oo|pp|qq|rr|ss|tt" },
				})
				commandArray = {} ;switch.switchSelector('bb')
					assert.is_same({ {["s1"]="Set Level 10"}}, commandArray)
				commandArray = {} ;switch.switchSelector('bb')
					assert.is_same({ {["s1"]="Set Level 10"}}, commandArray)
				commandArray = {} ;switch.switchSelector('Off')
					assert.is_same({ {["s1"]="Set Level 0"}}, commandArray)
				commandArray = {} ;switch.switchSelector('zzz')
					assert.is_same( {}, commandArray)
			end)

			it('should detect a selector', function()
					local switch = getDevice(domoticz, {
						['type'] = 'Light/Switch',
						['name'] = 's1',
						['state'] = 'bb',
						['rawData'] = { [1] = "10" },
						['additionalRootData'] = { ['switchType'] = 'Selector'},
						['additionalDataData'] = {
							levelNames = "Off|bb|cc"
						}
				})
				assert.is_same(10, switch.level)
				assert.is_same({'Off', 'bb', 'cc'}, _.values(switch.levelNames))

			end)

		end)

		describe('Scenes/Groups', function()

			it('should detect a scene', function()
				local scene = getDevice(domoticz, {
					['baseType'] = 'scene',
					['name'] = 'myScene',
				})

				assert.is_same('Description 1', scene.description)

				scene.switchOn()
				assert.is_same({ { ['Scene:myScene'] = 'On' } }, commandArray)

				commandArray = {}

				scene.switchOff()
				assert.is_same({ { ['Scene:myScene'] = 'Off' } }, commandArray)

				commandArray = {}

				scene.cancelQueuedCommands()

				assert.is_same({
					{ ['Cancel'] = { idx = 1, type = 'scene' } }
				}, commandArray)

				assert.is_false(scene.isHTTPResponse)
				assert.is_false(scene.isVariable)
				assert.is_false(scene.isTimer)
				assert.is_true(scene.isScene)
				assert.is_false(scene.isDevice)
				assert.is_false(scene.isGroup)
				assert.is_false(scene.isSecurity)
			end)

			it('should have generic functions for scenes', function()
				local scene = getDevice(domoticz, {
					['baseType'] = 'scene',
					['name'] = 'myScene',
				})
					assert.is_function(scene.protectionOff)
					assert.is_function(scene.protectionOn)
					assert.is_function(scene.setDescription)
					assert.is_function(scene.setIcon)
					assert.is_function(scene.setValues)
					assert.is_function(scene.rename)
			end)

			it('should handle generic methods for scenes', function()
				local scene = getDevice(domoticz, {
					['baseType'] = 'scene',
					['name'] = 'myScene',
					['state'] = 'On',
					['id'] = 1,
				})
				local res;

				domoticz.openURL = function(url)
					res = url;
				end

				scene.protectionOff()
				assert.is_same('http://127.0.0.1:8080/json.htm?type=updatescene&scenetype=0&protected=false&idx=1&name=myScene&description=Description+1', res)

				scene.protectionOn()
				assert.is_same('http://127.0.0.1:8080/json.htm?type=updatescene&scenetype=0&protected=true&idx=1&name=myScene&description=Description+1', res)

				scene.rename('a')
				assert.is_same('http://127.0.0.1:8080/json.htm?type=updatescene&scenetype=0&idx=1&name=a&description=Description+1', res)

				scene.setDescription('groupie')
				assert.is_same('http://127.0.0.1:8080/json.htm?type=updatescene&scenetype=0&idx=1&name=myScene&description=groupie', res)
			end)

			-- subdevices are tested in testDomoticz

			it('should detect a group', function()
				local group = getDevice(domoticz, {
					['baseType'] = 'group',
					['name'] = 'myGroup',
					['state'] = 'On'
				})

				assert.is_false(group.isHTTPResponse)
				assert.is_false(group.isVariable)
				assert.is_false(group.isTimer)
				assert.is_false(group.isScene)
				assert.is_false(group.isDevice)
				assert.is_true(group.isGroup)
				assert.is_false(group.isSecurity)

				assert.is_same('Description 1', group.description)

				group.switchOn()
				assert.is_same({ { ['Group:myGroup'] = 'On' } }, commandArray)

				commandArray = {}

				group.switchOff()
				assert.is_same({ { ['Group:myGroup'] = 'Off' } }, commandArray)

				commandArray = {}
				group.toggleGroup()
				assert.is_same({ { ['Group:myGroup'] = 'Off' } }, commandArray)

			end)

			 it('should have generic functions for groups', function()
				local group = getDevice(domoticz, {
					['baseType'] = 'group',
					['name'] = 'myGroup',
					['state'] = 'On'
				})
					assert.is_function(group.protectionOff)
					assert.is_function(group.protectionOn)
					assert.is_function(group.setDescription)
					assert.is_function(group.rename)
			end)

			it('should handle generic methods for group', function()
				local group = getDevice(domoticz, {
					['baseType'] = 'group',
					['name'] = 'myGroup',
					['state'] = 'On',
					['id'] = 1,
				})
				local res;

				domoticz.openURL = function(url)
					res = url;
				end

				group.protectionOff()
				assert.is_same('http://127.0.0.1:8080/json.htm?type=updatescene&scenetype=1&protected=false&idx=1&name=myGroup&description=Description+1', res)

				group.protectionOn()
				assert.is_same('http://127.0.0.1:8080/json.htm?type=updatescene&scenetype=1&protected=true&idx=1&name=myGroup&description=Description+1', res)

				group.rename('a')
				assert.is_same('http://127.0.0.1:8080/json.htm?type=updatescene&scenetype=1&idx=1&name=a&description=Description+1', res)

				group.setDescription('groupie')
				assert.is_same('http://127.0.0.1:8080/json.htm?type=updatescene&scenetype=1&idx=1&name=myGroup&description=groupie', res)
			end)
		end)

		describe('hardware', function()

			it('should detect hardware', function()
				local hardware = getDevice(domoticz, {
					['baseType'] = 'hardware',
					['name'] = 'myHardware',
					['hardwareType'] = 'myHardware type',
					['hardwareTypeValue'] = '234',
				})

				assert.is_false(hardware.isHTTPResponse)
				assert.is_false(hardware.isVariable)
				assert.is_false(hardware.isTimer)
				assert.is_false(hardware.isDevice)
				assert.is_false(hardware.isGroup)
				assert.is_false(hardware.isScene)
				assert.is_false(hardware.isSecurity)
				assert.is_true(hardware.isHardware)
			end)

			it('should return attributes correctly', function()
				local hardware = getDevice(domoticz, {
					['baseType'] = 'hardware',
					['name'] = 'myHardware',
					['hardwareType'] = 'myHardware type',
					['hardwareTypeValue'] = 234,
				})

				assert.is_equal(hardware.name,'myHardware' )
				assert.is_equal(hardware.hardwareType,'myHardware type' )
				assert.is_equal(hardware.hardwareTypeValue,234)
				assert.is_true(hardware.isHardware)

			end)
		end)

		it('should detect a huelight', function()
			local device = getDevice(domoticz, {
				['name'] = 'myHue',
				['state'] = 'Set Level: 88%',
				['type'] = 'Lighting 2'
			})

			assert.is_same( 88, device.level)

			device.toggleSwitch()
			assert.is_same({ { ["myHue"] = "Off" } }, commandArray)

			commandArray = {}
			device.switchOn()
			assert.is_same({ { ["myHue"] = "On" } }, commandArray)

			commandArray = {}
			device.switchOff()
			assert.is_same({ { ["myHue"] = "Off" } }, commandArray)
		end)

		it('should detect a Thermostat operating state device', function()
			local device = getDevice(domoticz, {
				['idx'] = 1,
				['type'] = 'General',
				['name'] = 'myThermostat operating state device',
				['subType'] = 'Thermostat Operating State',
				['nValue'] = 0,
			})

			assert.is_same('Idle', device.modeString)
			assert.is_same('Idle, Cooling, Heating', device.modes)
			assert.is_same(0, device.mode)

			commandArray = {}
			device.updateMode('Cooling')
			assert.is_same({ { ['UpdateDevice'] = { ['_trigger'] = true, ['idx'] = 1, ['nValue'] = 1, ['sValue'] = 'cooling' } }  }, commandArray)

		end)

		it('should detect a youless device', function()
			local device = getDevice(domoticz, {
				['name'] = 'myYouless',
				['type'] = 'YouLess Meter',
				['subType'] = 'YouLess counter',
				['rawData'] = { [1] = 123, [2] = 666},
				['additionalDataData'] = {
					['counterToday'] = '1.234 kWh'
				}
			})

			assert.is_same(123, device.counterDeliveredTotal)
			assert.is_same(666, device.powerYield)
			assert.is_same(1234, device.counterDeliveredToday)

			device.updateYouless(4, 5)
			assert.is_same({ {
				['UpdateDevice'] = {
					['_trigger'] = true,
					['idx'] = 1,
					['nValue'] = 0,
					['sValue'] = '4;5'
				}
			} }, commandArray)
		end)

		describe('Quiet device ( quietOn and quietOff', function()

			local commandArray = {}
			domoticz.openURL = function(url)
				return table.insert(commandArray, url)
			end

			local device = getDevice(domoticz, {
				['name'] = 'quietDevice',
				['state'] = 'On',
					['type'] = 'Light/Switch',
				['subType'] = 'RGBWW',
				['type'] = 'Color Switch'
			})

			it('should handle the quietOn method correctly )', function()
				commandArray = {}
				device.quietOn()
				assert.is_same({ 'http://127.0.0.1:8080/json.htm?type=command&param=udevice&nvalue=1&svalue=1&idx=1' }, commandArray)
			end)

			it('should handle the quietOff method correctly', function()
				commandArray = {}
				device.quietOff()
				assert.is_same({ 'http://127.0.0.1:8080/json.htm?type=command&param=udevice&nvalue=0&svalue=0&idx=1' }, commandArray)
			end)
		end)

		describe('Quiet device ( updateQuiet', function()

			local commandArray = {}
			domoticz.openURL = function(url)
				return table.insert(commandArray, url)
			end

			local device = getDevice(domoticz, {
				['name'] = 'quietDevice',
				['state'] = 'On',
					['type'] = 'Light/Switch',
				['subType'] = 'RGBWW',
				['type'] = 'Color Switch'
			})

			it('should handle the updateQuiet method correctly )', function()
				commandArray = {}
				device.updateQuiet() -- fail (no parms)
				assert.is_same({  }, commandArray) -- empty

				commandArray = {}
				device.updateQuiet('string only') -- only svalue
				assert.is_same({ 'http://127.0.0.1:8080/json.htm?type=command&param=udevice&idx=1&svalue=string+only'  }, commandArray)

				commandArray = {}
				device.updateQuiet(7) -- only nvalue
				assert.is_same({ 'http://127.0.0.1:8080/json.htm?type=command&param=udevice&idx=1&nvalue=7'  }, commandArray)

				commandArray = {}
				device.updateQuiet(7, '(string plus)') -- nvalue, svalue
				assert.is_same({ 'http://127.0.0.1:8080/json.htm?type=command&param=udevice&idx=1&svalue=%28string+plus%29&nvalue=7'   }, commandArray)

			end)

		end)

		describe('RGBW device #RGB', function()

			local commandArray = {}
			domoticz.utils = utils

			domoticz.openURL = function(url)
				return table.insert(commandArray, url)
			end

			domoticz.log	= function()
				return
			end

			local device = getDevice(domoticz, {
					['name'] = 'myRGBW',
					['state'] = 'Set Kelvin Level',
					['subType'] = 'RGBWW',
					['type'] = 'Color Switch'
				})

			assert.is_true(device.active)

			it('should handle the setKelvin method correctly', function()
				commandArray = {}
				device.setKelvin(5500)
				assert.is_same({ 'http://127.0.0.1:8080/json.htm?param=setkelvinlevel&type=command&idx=1&kelvin=5500' }, commandArray)
			end)

			it('should handle setWhitemode method correctly', function()
				commandArray = {}
				device.setWhiteMode()
				assert.is_same({ 'http://127.0.0.1:8080/json.htm?param=whitelight&type=command&idx=1' }, commandArray)
			end)

			local device = getDevice(domoticz, {
					['name'] = 'myRGBW',
					['state'] = 'Set Kelvin Level',
					['subType'] = 'RGBWW',
					['type'] = 'Color Switch',
					['hardwareType'] = 'YeeLight LED',
				})

			it('should handle increaseBrightness method correctly', function()
				commandArray = {}
				domoticz.log = function(message)
					msg = message
				end

				device.increaseBrightness()
				assert.is_not_same({ 'http://127.0.0.1:8080/json.htm?param=brightnessup&type=command&idx=1' }, commandArray)
				assert.is_same('If you believe this is not correct, please report on the forum.', msg)
			end)

			it('should handle decreaseBrightness method correctly', function()
				commandArray = {}
				domoticz.log = function(message)
					msg = message
				end

				device.decreaseBrightness()
				assert.is_not_same({ 'http://127.0.0.1:8080/json.htm?param=brightnessdown&type=command&idx=1' }, commandArray)
				assert.is_same('If you believe this is not correct, please report on the forum.', msg)
			end)

			it('should handle setNightMode method correctly', function()
				commandArray = {}
				device.setNightMode()
				assert.is_same({ 'http://127.0.0.1:8080/json.htm?param=nightlight&type=command&idx=1' }, commandArray)
			end)

			it('should handle setRGB method correctly', function()
				commandArray = {}
				device.setRGB(255, 0, 0)
				assert.is_same({ 'http://127.0.0.1:8080/json.htm?param=setcolbrightnessvalue&type=command&idx=1&hue=0&brightness=100&iswhite=false' }, commandArray)
			end)

			it('should handle setHex method correctly', function()
				commandArray = {}
				assert.is_nil(device.setHex(15,31,47))
				assert.is_same({'http://127.0.0.1:8080/json.htm?type=command&param=setcolbrightnessvalue&idx=1&brightness=18.43137254902&hex=0f1f2f&iswhite=false'},commandArray)
			end)

			it('should handle setColor method with wrong values correctly' , function()
				commandArray = {}
				assert.is_false(device.setColor(15,31,447)) -- Should return false because of out of range parms
				assert.is_same({},commandArray)
			end)

			it('should handle setColor method correctly',function()
				commandArray = {}
				assert.is_nil(device.setColor(15,31,44))
				assert.is_same({'http://127.0.0.1:8080/json.htm?type=command&param=setcolbrightnessvalue&idx=1&brightness=1&color={"m":3,"t":0,"cw":0,"ww":0,"r":15,"g":31,"b":44}'},commandArray)
			end)

			it('should handle setColorBrightness method correctly',function()
				commandArray = {}
				assert.is_nil(device.setColorBrightness(15,31,44))
				assert.is_same({'http://127.0.0.1:8080/json.htm?type=command&param=setcolbrightnessvalue&idx=1&brightness=1&color={"m":3,"t":0,"cw":0,"ww":0,"r":15,"g":31,"b":44}'},commandArray)
			end)

			it('should handle setDiscomode method correctly',function()
				commandArray = {}

				domoticz.log = function(message)
					msg = message
				end

				device.setDiscoMode(8)
				assert.is_not_same({ 'http://127.0.0.1:8080/json.htm?param=discomodenum8&type=command&idx=1' }, commandArray)
				assert.is_same('If you believe this is not correct, please report on the forum.', msg)
			end)

			it('should handle setHue method correctly',function()
				commandArray = {}
				assert.is_nil(device.setHue(180,11,true))
				assert.is_same({ 'http://127.0.0.1:8080/json.htm?type=command&param=setcolbrightnessvalue&idx=1&brightness=11&hue=180&iswhite=true' }, commandArray)
			end)

			it('should handle setHue method with wrong parms correctly',function()
				commandArray = {}
				assert.is_false(device.setHue(180,1111))
				assert.is_false(device.setHue(1180,11))
				assert.is_false(device.setHue(180,11,"white"))
				assert.is_same({}, commandArray)
			end)

			it('should handle get Device with type color Switch correctly',function()
				device = getDevice(domoticz, {
					['name'] = 'myRGBW',
					['state'] = 'Set To White',
					['type'] = 'Color Switch',
				})
				assert.is_true(device.active)
			end)

			it('should handle getDevice with subtype RGBWW with state NightMode correctly',function()
				device = getDevice(domoticz, {
					['name'] = 'myRGBW',
					['state'] = 'NightMode',
					['subType'] = 'RGBWW',
					['type'] = 'Color Switch'
				})
				assert.is_true(device.active)
			end)

			it('should handle getDevice with subtype RGBWW with state Off correctly',function()
				device = getDevice(domoticz, {
					['name'] = 'myRGBW',
					['state'] = 'Off',
					['subType'] = 'RGBWW',
					['type'] = 'Color Switch'
				})
			end)
		end)

		describe('Kodi', function()

			local device = getDevice(domoticz, {
				['name'] = 'myDevice',
				['type'] = 'bla',
				['hardwareType'] = 'Kodi Media Server'
			})

			it('should switchOff', function()
				device.kodiSwitchOff()
				assert.is_same({ { ['myDevice'] = 'Off' } }, commandArray)
			end)

			it('should stop', function()
				device.kodiStop()
				assert.is_same({ { ['myDevice'] = 'Stop' } }, commandArray)
			end)

			it('should play', function()
				device.kodiPlay()
				assert.is_same({ { ['myDevice'] = 'Play' } }, commandArray)
			end)

			it('should pause', function()
				device.kodiPause()
				assert.is_same({ { ['myDevice'] = 'Pause' } }, commandArray)
			end)

			it('should set volume', function()
				device.kodiSetVolume(22)
				assert.is_same({ { ['myDevice'] = 'Set Volume 22' } }, commandArray)
			end)

			it('should not set volume if not in range', function()
				local msg, tp
				local utils = device._getUtilsInstance()

				utils.log = function(message, type)
					msg = message
					tp = type
				end
				device.kodiSetVolume(101)

				assert.is_same({}, commandArray)
				assert.is_same('Volume must be between 0 and 100. Value = 101', msg)
				assert.is_same(LOG_ERROR, tp)

				tp = ''
				msg = ''

				device.kodiSetVolume(-1)
				assert.is_same({}, commandArray)
				assert.is_same('Volume must be between 0 and 100. Value = -1', msg)
				assert.is_same(LOG_ERROR, tp)
			end)

			it('should play a playlist', function()
				device.kodiPlayPlaylist('daList', 12)
				assert.is_same({ { ['myDevice'] = 'Play Playlist daList 12' } }, commandArray)

				commandArray = {}
				device.kodiPlayPlaylist('daList')
				assert.is_same({ { ['myDevice'] = 'Play Playlist daList 0' } }, commandArray)
			end)

			it('should play favorites', function()
				device.kodiPlayFavorites(12)
				assert.is_same({ { ['myDevice'] = 'Play Favorites 12' } }, commandArray)

				commandArray = {}

				device.kodiPlayFavorites()
				assert.is_same({ { ['myDevice'] = 'Play Favorites 0' } }, commandArray)
			end)

			it('should execute an addon', function()
				device.kodiExecuteAddOn('daAddOn')
				assert.is_same({ { ['myDevice'] = 'Execute daAddOn' } }, commandArray)
			end)
		end)

	end)

	it('should instantiate', function()
		assert.is_not_nil(device)
	end)

	it('should have a name', function()
		assert.is_same('myDevice', device.name)
	end)

	it('should be marked as changed when the device was changed', function()
		assert.is_true(device.changed)
	end)

	it('should not be marked as changed when the device was not changed', function()
		local device = getDevice_(domoticz, 'myDevice', 'On', false)
		assert.is_false(device.changed)
	end)

	it('should not have a state when it doesnt have one', function()
		local device = getDevice_(domoticz, 'myDevice', nil, false)
		assert.is_nil(device.state)
	end)

	it('should extract level', function()
		local device = getDevice_(domoticz, 'myDevice', 'Set Level: 55%', false)
		assert.is_same('On', device.state)
		assert.is_number(device.level)
		assert.is_same(55, device.level)
	end)

	it('should have a bState/active when possible', function()
		local device = getDevice_(domoticz, 'myDevice', 'Set Level: 55%', false)
		assert.is_true(device.bState)
		assert.is_true(device.active)

		device = getDevice_(domoticz, 'myDevice', '', false)
		assert.is_false(device.bState)
		assert.is_false(device.active)

		device = getDevice_(domoticz, 'myDevice', 'On', false)
		assert.is_true(device.bState)
		assert.is_true(device.active)

		local states = device._States

		_.forEach(states, function(value, key)
			device = getDevice_(domoticz, 'myDevice', key, false)
			if (value.b) then
				assert.is_true(device.bState)
				assert.is_true(device.active)
			else
				assert.is_false(device.bState)
				assert.is_true(device.active)
			end
		end)
	end)

	it('should set the state', function()
		local cmd = device.setState('Off')
		assert.is_table(cmd)
		assert.is_same({["myDevice"]="Off"}, cmd._latest)
	end)

	describe('Updating', function()
		it('should send generic update commands', function()
			device.update(1,2,true)
			assert.is_same({{["UpdateDevice"]={idx=1, nValue=1, sValue="2", protected=true, _trigger=true}}}, commandArray)
		end)

		it('should send generic update commands', function()
			device.update(1, 2, true).silent()
			assert.is_same({{["UpdateDevice"]={idx=1, nValue=1, sValue="2", protected=true}}}, commandArray)
		end)
	end)

end)
