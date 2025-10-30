/***************************************************************************************************************************/
/* robbit(Two-wheeled Self Balancing Car Project) since 2025-10 Copyright(c) 2025 Archlab. Science Tokyo                   */
/* Released under the MIT license https://opensource.org/licenses/mit                                                      */
/*                                                                                                                         */
/* This program links to the MadgwickAHRS library licensed under the GNU Lesser General Public License v2.1 (LGPL v2.1) or */
/* link to the MadgwickAHRS library licensed under later versions.                                                         */
/*                                                                                                                         */
/* The source code and licence terms for the MadgwickAHRS library are contained                                            */
/* in https://github.com/arduino-libraries/MadgwickAHRS                                                                    */
/***************************************************************************************************************************/

#include <Wire.h>
#include "MPU6050.h"
#include <MadgwickAHRS.h>
#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEserver.h>

//BLE setting
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"
BLECharacteristic *pCharacteristic;
/******************************************************************************************/
#define MOTOR_STBY    D0  // pin assignment of XIAO ESP32C3
#define MOTOR_AIN1    D1  // pin assignment of XIAO ESP32C3
#define MOTOR_AIN2    D2  // pin assignment of XIAO ESP32C3
#define MOTOR_PWM     D3  // pin assignment of XIAO ESP32C3
/******************************************************************************************/
#define D_V_MAX      120  // 120, PWM Max (V_MAX + PWM_BASE is the real max)
#define D_I_MAX      0.2  // 0.2, 
#define D_PWM_GAIN   1.0  // 1.0, 
#define D_PWM_BASE    40  //  40, 
#define D_LOOP_HZ    500  // 300, Hz of main loop
#define D_TARGET   -12.2  // target roll
/******************************************************************************************/
float target    =  D_TARGET; // target angle
float Kp        =    900; // P Gain
float Ki        =   3000; // I Gain
float Kd        =     20; // D Gain, 38
float stoptheta =     40; // stop theta angle 
/******************************************************************************************/
MPU6050 mpu;
Madgwick MadgwickF;
float roll, dt;
float P, I, D, U, preP;
float power, Freq, pwm_base, pwm, vmax;

int16_t ax, ay, az, gx, gy, gz;
unsigned int loops = 0;
unsigned int pwm_int;
volatile unsigned int pre_timer = 0;
volatile unsigned int timer = 0;
unsigned int time_loop;
unsigned int usec_loop;

char r_buf[256];
/******************************************************************************************/

String activeParameterForRead = "target"; 

class MyCallbacks: public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pCharacteristic) {
    String status = pCharacteristic->getValue();
    int spaceindex = status.indexOf(' '); //index of space

    String parameter = status.substring(0, spaceindex); //parameter name
    float value = status.substring(spaceindex, status.length()).toFloat();

    if (parameter == "1") {
      target = value;
    } else if(parameter == "2"){
      Kp = value;
    } else if(parameter == "3"){
      Ki = value;
    } else if(parameter == "4"){
      Kd = value;
    } else if(parameter == "5"){
      pwm_base = value;
    } else if(parameter == "6"){
      vmax = value;
    }
  }

  void onRead(BLECharacteristic *pCharacteristic) {
    
  }

 };

void setup() 
{
  Wire.begin();
  Wire.setClock(400000);

  Serial.begin(115200);
  mpu.initialize();
  delay(300);

  BLEDevice::init("Bcar-ESP32");
  BLEServer *pServer = BLEDevice::createServer();
  BLEService *pService = pServer->createService(SERVICE_UUID);
  pCharacteristic = pService->createCharacteristic(
                                        CHARACTERISTIC_UUID,
                                        BLECharacteristic::PROPERTY_READ | 
                                        BLECharacteristic::PROPERTY_WRITE
                                      );
  pCharacteristic->setCallbacks(new MyCallbacks());
  pCharacteristic->setValue("Enter parameter and value");
  pService->start();
  BLEAdvertising *pAdvertising = pServer->getAdvertising();
  pAdvertising->start();

  pinMode(MOTOR_AIN1,  OUTPUT);
  pinMode(MOTOR_AIN2,  OUTPUT);
  pinMode(MOTOR_STBY,  OUTPUT);
  digitalWrite(MOTOR_AIN1,  LOW);
  digitalWrite(MOTOR_AIN2,  LOW); 
  digitalWrite(MOTOR_STBY, HIGH);

  target   = D_TARGET;
  Freq     = D_LOOP_HZ;
  pwm_base = D_PWM_BASE;
  vmax = D_V_MAX;

  MadgwickF.begin(D_LOOP_HZ);
  MadgwickF.setGain(0.9); // Note

  for (int i=0; i<D_LOOP_HZ; i++){
    mpu.getMotion6(&ay, &ax, &az, &gy, &gx, &gz);
    MadgwickF.updateIMU(gz/131.0, gy/131.0, gx/131.0, az/16384.0, ay/16384.0, ax/16384.0);
    delayMicroseconds(1000000/D_LOOP_HZ);
  }
  MadgwickF.setGain(0.1); // Note

  dt = 1.0 / Freq;
  usec_loop = 1000000 / Freq;
}

/******************************************************************************************/
void loop()
{
  loops++;
 
  mpu.getMotion6(&ay, &ax, &az, &gy, &gx, &gz);
  MadgwickF.updateIMU(gz/131.0, gy/131.0, gx/131.0, az/16384.0, ay/16384.0, ax/16384.0);
  roll = MadgwickF.getRoll() - 90.0; // Note
  
  ///// PID control
  P  = (target - roll) / 90.0; 
  if(fabsf(I + P * dt) < D_I_MAX)  I += P * dt;  // cap
  D  = (P - preP) / dt;
  preP = P;

  power = Kp * P + Ki * I + Kd * D;
  pwm = (fabsf(power)>vmax) ? vmax : fabsf(power);
  pwm_int = (pwm + pwm_base) * D_PWM_GAIN;         // Note
  if (pwm_int > 255) pwm_int = 255;

  int motor_ctrl = 0;
  if (roll < (target -stoptheta) || (target + stoptheta) < roll) {
    power = pwm = pwm_int = P = I = D = 0;
    motor_ctrl = 0;
    target =  D_TARGET;
  }else{
     motor_ctrl = (power < 0) ? 2 : 1;
  }

  analogWrite(MOTOR_PWM, pwm_int);  // pwm ranges from 0 to 255
  if     (motor_ctrl==1) { digitalWrite(MOTOR_AIN2,  LOW); digitalWrite(MOTOR_AIN1, HIGH); }
  else if(motor_ctrl==2) { digitalWrite(MOTOR_AIN2, HIGH); digitalWrite(MOTOR_AIN1,  LOW); }
  else                   { digitalWrite(MOTOR_AIN2,  LOW); digitalWrite(MOTOR_AIN1,  LOW); }

  /***** adjust the target *****/
  static int motor_cnt = 0;
  if     (motor_ctrl==1) motor_cnt++;
  else if(motor_ctrl==2) motor_cnt--;
   if (loops%D_LOOP_HZ == 0){ // every second
     if(motor_cnt >  0.1*D_LOOP_HZ) target = target + 0.05;
     if(motor_cnt < -0.1*D_LOOP_HZ) target = target - 0.05;
     motor_cnt = 0;
   }

  if (loops%63 == 0){
    char buf[256];
    sprintf(buf, "%5d: %7.2f %6d %7.2f\n", loops, target, time_loop, roll);
    Serial.print(buf);
  }

  sprintf(r_buf, "%.2f, %.2f, %.2f, %.2f, %.2f, %.2f", target, Kp, Ki, Kd, pwm_base, vmax);
  pCharacteristic->setValue(r_buf);
  
  while ((timer - pre_timer) < usec_loop) {
    timer = micros(); // time in usec
  }
  time_loop = timer - pre_timer; // for debug
  pre_timer = timer;
}
/******************************************************************************************/
