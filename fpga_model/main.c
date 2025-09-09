/******************************************************************************************/
/* Self Balancing Car Project since 2025-01      Copyright(c) 2025 Archlab. Science Tokyo */
/* main.c version 2025-05-16b                                                             */
/* Released under the MIT license https://opensource.org/licenses/mit                     */
/* some functions are from Arduino library                                                */
/******************************************************************************************/
#include <cstdint>
#include <cmath>
//#include <stdio.h>
#include "my_printf.h"
#include "st7789.h"
#include "perf.h"

/******************************************************************************************/
// MadgwickAHRS.h
/******************************************************************************************/
// Variable declaration
class Madgwick
{
    private:
        static float invSqrt(float x);
        float beta; // algorithm gain
        float q0;
        float q1;
        float q2;
        float q3; // quaternion of sensor frame relative to auxiliary frame
        float invSampleFreq;
        float roll;
        float pitch;
        float yaw;
        char anglesComputed;
        void computeAngles();

        //-------------------------------------------------------------------------
        // Function declarations
    public:
        Madgwick(void);
        void begin(float sampleFrequency) { invSampleFreq = 1.0f / sampleFrequency; }
        void setGain(float gain) { beta = gain; } // add my function 2024-12-5
        void updateIMU(float gx, float gy, float gz, float ax, float ay, float az);
        float getRoll()
        {
            if (!anglesComputed)
                computeAngles();
            return roll * 57.29578f; //radian->degree
        }
};

/******************************************************************************************/
// MadgwickAHRS.c
/******************************************************************************************/
// Definitions

#define sampleFreqDef 512.0f // sample frequency in Hz
#define betaDef 0.1f         // 2 * proportional gain

/******************************************************************************************/
// Functions

//------------------------------------------------------------------------------------------
// AHRS algorithm update

Madgwick::Madgwick()
{
    beta = betaDef;
    q0 = 1.0f;
    q1 = 0.0f;
    q2 = 0.0f;
    q3 = 0.0f;
    invSampleFreq = 1.0f / sampleFreqDef;
    anglesComputed = 0;
}

//-----------------------------------------------------------------------------------------
// IMU algorithm update

void Madgwick::updateIMU(float gx, float gy, float gz, float ax, float ay, float az)
{
    float recipNorm;
    float s0, s1, s2, s3;
    float qDot1, qDot2, qDot3, qDot4;
    float _2q0, _2q1, _2q2, _2q3, _4q0, _4q1, _4q2, _8q1, _8q2, q0q0, q1q1, q2q2, q3q3;

    // Convert gyroscope degrees/sec to radians/sec
    gx *= 0.0174533f;
    gy *= 0.0174533f;
    gz *= 0.0174533f;

    // Rate of change of quaternion from gyroscope
    qDot1 = 0.5f * (-q1 * gx - q2 * gy - q3 * gz);
    qDot2 = 0.5f * (q0 * gx + q2 * gz - q3 * gy);
    qDot3 = 0.5f * (q0 * gy - q1 * gz + q3 * gx);
    qDot4 = 0.5f * (q0 * gz + q1 * gy - q2 * gx);

    // Compute feedback only if accelerometer measurement valid
    // (avoids NaN in accelerometer normalisation)
    if (!((ax == 0.0f) && (ay == 0.0f) && (az == 0.0f)))
    {

        // Normalise accelerometer measurement
        recipNorm = invSqrt(ax * ax + ay * ay + az * az);
        ax *= recipNorm;
        ay *= recipNorm;
        az *= recipNorm;

        // Auxiliary variables to avoid repeated arithmetic
        _2q0 = 2.0f * q0;
        _2q1 = 2.0f * q1;
        _2q2 = 2.0f * q2;
        _2q3 = 2.0f * q3;
        _4q0 = 4.0f * q0;
        _4q1 = 4.0f * q1;
        _4q2 = 4.0f * q2;
        _8q1 = 8.0f * q1;
        _8q2 = 8.0f * q2;
        q0q0 = q0 * q0;
        q1q1 = q1 * q1;
        q2q2 = q2 * q2;
        q3q3 = q3 * q3;

        // Gradient decent algorithm corrective step
        s0 = _4q0 * q2q2 + _2q2 * ax + _4q0 * q1q1 - _2q1 * ay;
        s1 = _4q1 * q3q3 - _2q3 * ax + 4.0f * q0q0 * q1 -
            _2q0 * ay - _4q1 + _8q1 * q1q1 + _8q1 * q2q2 + _4q1 * az;
        s2 = 4.0f * q0q0 * q2 + _2q0 * ax + _4q2 * q3q3 -
            _2q3 * ay - _4q2 + _8q2 * q1q1 + _8q2 * q2q2 + _4q2 * az;
        s3 = 4.0f * q1q1 * q3 - _2q1 * ax + 4.0f * q2q2 * q3 - _2q2 * ay;

        // normalise step magnitude
        recipNorm = invSqrt(s0 * s0 + s1 * s1 + s2 * s2 + s3 * s3);
        s0 *= recipNorm;
        s1 *= recipNorm;
        s2 *= recipNorm;
        s3 *= recipNorm;

        // Apply feedback step
        qDot1 -= beta * s0;
        qDot2 -= beta * s1;
        qDot3 -= beta * s2;
        qDot4 -= beta * s3;
    }

    // Integrate rate of change of quaternion to yield quaternion
    q0 += qDot1 * invSampleFreq;
    q1 += qDot2 * invSampleFreq;
    q2 += qDot3 * invSampleFreq;
    q3 += qDot4 * invSampleFreq;

    // Normalise quaternion
    recipNorm = invSqrt(q0 * q0 + q1 * q1 + q2 * q2 + q3 * q3);
    q0 *= recipNorm;
    q1 *= recipNorm;
    q2 *= recipNorm;
    q3 *= recipNorm;
    anglesComputed = 0;
}

//------------------------------------------------------------------------------------------
float Madgwick::invSqrt(float x)
{
    float halfx = 0.5f * x;
    float y = x;
    long i = *(long *)&y;
    i = 0x5f3759df - (i >> 1);
    y = *(float *)&i;
    y = y * (1.5f - (halfx * y * y));
    y = y * (1.5f - (halfx * y * y));
    return y;
}

//------------------------------------------------------------------------------------------
void Madgwick::computeAngles()
{
    roll = atan2f(q0 * q1 + q2 * q3, 0.5f - q1 * q1 - q2 * q2);
    pitch = asinf(-2.0f * (q1 * q3 - q0 * q2));
    yaw = atan2f(q1 * q2 + q0 * q3, 0.5f - q2 * q2 - q3 * q3);
    anglesComputed = 1;
}

/******************************************************************************************/
int constrain(int value, int min, int max){
    if (value<min) return min;
    if (value>max) return max;
    return value;
}

/******************************************************************************************/
#define COLOR_BLACK   0
#define COLOR_BLUE    1
#define COLOR_GREEN   2
#define COLOR_CYAN    3
#define COLOR_RED     4
#define COLOR_MAGENTA 5
#define COLOR_YELLOW  6
#define COLOR_WHITE   7
/******************************************************************************************/
///// MMIO
int *const MPU_ADDR_ayax = (int *)0x30000000;
int *const MPU_ADDR_gxaz = (int *)0x30000004;
int *const MPU_ADDR_gzgy = (int *)0x30000008;
int *const MPU_ADDR_TIME = (int *)0x30000010;
///// CTRL
int *const MTR_ADDR_ctrl = (int *)0x30000040;
///// button
int *const BUTTON_ADDR   = (int *)0x30000044;

/******************************************************************************************/
#define FREQ         100   // Operation frequency in Mz
#define LOOP_HZ      220  // Hz of main loop
#define PWM_BASE      38   // Incremental PWM signal 
#define V_MIN          0   // PWM Min
#define V_MAX        110   // PWM Max (V_MAX + PWM_BASE is the real max)
#define I_MAX        0.4   // Anti-windup 
#define PWM_GAIN     1.0   // PWM signal magnitude
#define STOPTHETA     50   // Motion Stop Angle
#define FILTER_GAIN  0.1   // Madgwick Filter Gain
#define LOOP_INIT    500   //  
/******************************************************************************************/
#define TARGET       -65   // robbit target angle * 10, horiazon = 0.0
#define P_GAIN       1200  // Size of proportional element
#define I_GAIN       3000  // Size of integral element
#define D_GAIN         38  // Size of differential component
/******************************************************************************************/
typedef struct parameters
{
    float Kp = P_GAIN;
    float Ki = I_GAIN;
    float Kd = D_GAIN;
    float target = TARGET * 0.1; 
    float Vmin = V_MIN;
    float Vmax = V_MAX;
    float pwm_base = PWM_BASE;
} Parameters;

int main() {
    pg_lcd_reset();
    Madgwick MadgwickFilter; 

    Parameters parameter;
    float roll, dt, P, I, D, preP;
    float power, pwm;
    int16_t ax, ay, az, gx, gy, gz;

    MadgwickFilter.begin((float)LOOP_HZ);
    MadgwickFilter.setGain(FILTER_GAIN);
    dt = 1.0 / (float)LOOP_HZ;

    unsigned int loops = 0;
    int init = 1;
    volatile unsigned int pre_timer = 0;
    volatile unsigned int timer = 0;
    unsigned int t1 = 1;
    unsigned int t2 = 1;
    volatile unsigned int button = 0;
    unsigned int pwm_int;
    int param_select = 1;
    
    while (1) {
        loops++;

        {
            //get acceralation and angular velocity 
            int16_t ax, ay, az, gx, gy, gz;
            unsigned int data;
            data = *(MPU_ADDR_ayax);
            ax = data & 0xffff;
            ay = data >> 16;

            data = *(MPU_ADDR_gxaz);
            az = data & 0xffff;
            gx = data >> 16;

            data = *(MPU_ADDR_gzgy);
            gy = data & 0xffff;
            gz = data >> 16;

            //calculation of roll
            MadgwickFilter.updateIMU(-gz / 131.0, gy / 131.0, gx / 131.0,
                                     -az / 16384.0, ay / 16384.0, ax / 16384.0);
            roll = MadgwickFilter.getRoll();
        }
        
        // PID control
        P = (parameter.target - roll) / 90.0;
        if(fabsf(I + P * dt) < I_MAX)  I += P * dt;  // cap
        D = (P - preP) / dt;
        preP = P;

        power = parameter.Kp * P + parameter.Ki * I + parameter.Kd * D;

        //PWM control
        pwm = (fabsf(power)>parameter.Vmax) ? parameter.Vmax : fabsf(power);
        pwm_int = (pwm + parameter.pwm_base) * PWM_GAIN;         
        if (pwm_int > 255) pwm_int = 255;

        //motor control signal
        int motor_ctrl = 0;
        if (loops <  LOOP_INIT ||
            roll < (parameter.target - STOPTHETA) || (parameter.target + STOPTHETA) < roll) {
            power = pwm = pwm_int = P = I = D = 0;
            motor_ctrl = 0;
        }
        else {
            motor_ctrl = (power < 0) ? 2 : 1;
        }
        
        *(MTR_ADDR_ctrl) = (pwm_int & 0xff) | (motor_ctrl << 16); // control motor

        //Recording of elapsed time
        timer = *(MPU_ADDR_TIME);
        if(loops%100==0) {
            t2 = t1;
            t1 = timer;
        }

        /***** change parameter by bush button *****/
        /****************************************************************************/
        if (loops%100==0){
            
            button = *(BUTTON_ADDR);  // check button pushing

            if (button == 3) {
                param_select = (param_select==6) ? 1 : param_select+1;
            }

            if (param_select==1) { ///// target
                if     (button == 1) parameter.target -= 0.1; // 0.001;
                else if(button == 2) parameter.target += 0.1; // 0.001;
            }
            if (param_select==2) { ///// P
                if     (button == 1) parameter.Kp = parameter.Kp * 0.98;
                else if(button == 2) parameter.Kp = parameter.Kp * 1.02;
            }
            if (param_select==3) { ///// I
                if     (button == 1) parameter.Ki = parameter.Ki * 0.98;
                else if(button == 2) parameter.Ki = parameter.Ki * 1.02;
            }
            if (param_select==4) { ///// D
                if     (button == 1) parameter.Kd = parameter.Kd * 0.98;
                else if(button == 2) parameter.Kd = parameter.Kd * 1.02;
            }
            if (param_select==5) { ///// PWM_BASE
                if     (button == 1) parameter.pwm_base -= 1.0;
                else if(button == 2) parameter.pwm_base += 1.0;
            }
            if (param_select==6) { ///// Vmax
                if     (button == 1) parameter.Vmax -= 1.0;
                else if(button == 2) parameter.Vmax += 1.0;
            }
        }

        /***** prints info to st7789 display  *****/
        /****************************************************************************/
        if (init) {
            init = 0;
            pg_lcd_set_pos(0, 0);
            pg_lcd_prints_color("Self-BCar v3\n", COLOR_MAGENTA);
            pg_lcd_prints("roll\n");
            pg_lcd_prints("power\n");
            pg_lcd_prints("PWM\n");
            pg_lcd_prints("\n");
            pg_lcd_prints_color("target\n",   COLOR_CYAN);
            pg_lcd_prints_color("P_gain\n",   COLOR_CYAN);
            pg_lcd_prints_color("I_gain\n",   COLOR_CYAN);
            pg_lcd_prints_color("D_gain\n",   COLOR_CYAN);
            pg_lcd_prints_color("PWM_Base\n", COLOR_YELLOW);
            pg_lcd_prints_color("Vmax\n",     COLOR_YELLOW);
            pg_lcd_prints("loops\n");  //pg_lcd_prints("loop\n");
            pg_lcd_prints("timer\n");
            pg_lcd_prints("freq\n");
        }
        char buf[32];

        pg_lcd_set_pos(13,0); sprintf_(buf, "%2d\n", param_select);    pg_lcd_prints(buf);
        switch (loops % 13)
        {
        case 0:
            /* code */
            pg_lcd_set_pos(8, 1); sprintf_(buf, "%7.2f\n",roll);    pg_lcd_prints(buf);
            break;
        case 1:
            pg_lcd_set_pos(6, 2); sprintf_(buf, "%9.2f\n",  power); pg_lcd_prints(buf);
            break;
        case 2:
            pg_lcd_set_pos(6, 3); sprintf_(buf, "%9.2f\n",  pwm);   pg_lcd_prints(buf);
            break;
        case 3:
            pg_lcd_set_pos(8, 5); sprintf_(buf, "%7.2f\n",parameter.target);pg_lcd_prints_color(buf, COLOR_CYAN);
            break;
        case 4:
            pg_lcd_set_pos(8, 6); sprintf_(buf, "%7.2f\n",  parameter.Kp);  pg_lcd_prints_color(buf, COLOR_CYAN);
            break;
        case 5:
            pg_lcd_set_pos(8, 7); sprintf_(buf, "%7.2f\n",  parameter.Ki);  pg_lcd_prints_color(buf, COLOR_CYAN);
            break;
        case 6:
            pg_lcd_set_pos(8, 8); sprintf_(buf, "%7.2f\n",  parameter.Kd);  pg_lcd_prints_color(buf, COLOR_CYAN);
            break;
        case 7:
            pg_lcd_set_pos(8, 9); sprintf_(buf, "%7.2f\n",  parameter.pwm_base);pg_lcd_prints_color(buf, COLOR_YELLOW);
            break;
        case 8:
            pg_lcd_set_pos(8,10); sprintf_(buf, "%7.2f\n",  parameter.Vmax);  pg_lcd_prints_color(buf, COLOR_YELLOW);
            break;
        case 9:
            pg_lcd_set_pos(5,11); sprintf_(buf, "%10d\n", loops);   pg_lcd_prints(buf);
            break;
        case 10:
            pg_lcd_set_pos(5,12); sprintf_(buf, "%10d\n", timer);   pg_lcd_prints(buf);
            break;
        case 11:
            pg_lcd_set_pos(5,13); sprintf_(buf, "%10d\n", (FREQ * 100000)/(t1 - t2)); pg_lcd_prints(buf);
            break;
        case 12:
            pg_lcd_set_pos(2,14);
            if (motor_ctrl==0) pg_lcd_prints_color("*** STOP***\n", COLOR_RED);
            if (motor_ctrl==1) pg_lcd_prints_color("*** FWD ***\n", COLOR_CYAN);
            if (motor_ctrl==2) pg_lcd_prints_color("*** REV ***\n", COLOR_BLACK);
        default:
            break;
        }
        /****************************************************************************/        
        
        while(1){ ///// delay
            timer = *(MPU_ADDR_TIME);
            if (abs(timer - pre_timer + 1) >= ((FREQ * 1000)/LOOP_HZ)) break;
        }
        pre_timer = timer;
        
    }
    return 0;
}
/******************************************************************************************/