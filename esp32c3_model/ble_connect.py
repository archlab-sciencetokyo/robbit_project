import asyncio
from bleak import BleakClient, BleakScanner

par_name = ["target", "Kp", "Ki", "Kd", "pwm_base", "V_MAX"]

async def run():

    found_target = True
    #devices = await discover()
    devices = await BleakScanner.discover() # New way

    uuid_target = ""
    target_adress = ""

    #Search ESP32C3
    for info in devices:
        if(info.name == "Bcar-ESP32"):
            target_adress = info.address
            found_target = False

    if found_target:
        print("BLE connection error : Make sure robbit is switched on")
        return
    
    async with BleakClient(target_adress) as client:

        # check connection
        if client.is_connected:
            print(f"connected {client.address}")

        #get uuid
        services = client.services
        for service in services:
            print(f"Service_uuid: {service.uuid}")
            for characteristic in service.characteristics:
                #print(f"  キャラクタリスティックUUID: {characteristic.uuid}")
                uuid_target = characteristic.uuid

        print(f"MAC_adress : {target_adress}")
        print(f"Characteristic_uuid : {uuid_target}")
        print("input (\"parameter number\" \"value\") -> ", end="")
       
        while 1:

            order = input()
            parameter = order.split()

            match parameter[0]:

                #read parameters
                case 'r':
                    data = await client.read_gatt_char(uuid_target)
                    my_string = data.decode('utf-8').split()
                    print("*-------------------------------------*")
                    for i in range(len(my_string)):
                        print(f'{par_name[i]} : {my_string[i]}')
                    print("*-------------------------------------*")
                    print("input (\"parameter number\" \"value\") -> ", end="")

                #change parameter value
                case '1' | '2' | '3' | '4' | '5' | '6':
                    value = bytearray(order.encode('utf-8'))
                    await client.write_gatt_char(uuid_target, value)
                    print(f"write {par_name[int(parameter[0])-1]} = {parameter[1]}")
                    print("input (\"parameter number\" \"value\") -> ", end="")

                #disconnect ESP32C3
                case 'e':
                    await client.disconnect()
                    print("finish connection")
                    break

                case _:
                    print("input (\"parameter number\" \"value\") -> ")

asyncio.run(run())
