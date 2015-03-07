//
//  ViewController.m
//  Kaji_ALPS
//
//  Created by haruhito on 2015/03/07.
//  Copyright (c) 2015年 Fuji Haruhito. All rights reserved.
//

#import "ViewController.h"
//Bluetooth LE
#import <CoreBluetooth/CoreBluetooth.h>
//Audio
#import <AVFoundation/AVFoundation.h>

/// デバイス名
#define DEVICE_NAME    @"Mul2001A"

/// サービスUUID
#define SENSOR_SERVICE_UUID    @"56396415-E301-A7B4-DC48-CED976D324E9"

/// キャラクタリスティックUUID
#define SENSOR_CHARACTERISTIC_UUID  @"38704154-9A8C-8F8F-4449-89C0AF8A0402"

const NSString *key_acc_x = @"acc_x";
const NSString *key_acc_y = @"acc_y";
const NSString *key_acc_z = @"acc_z";

@interface ViewController ()
<CBCentralManagerDelegate,CBPeripheralDelegate>
{
    ///Bluetooth LE
    //// CentralManager
    CBCentralManager    *manager;
    //// Peripheral
    CBPeripheral    *device;
    
    /// ログデータ用の変数
    float datMx, datMy, datMz;
    float datAx, datAy, datAz;
    float datUv, datLx;
    float datHm, datTm;
    float datPs;

    //加速度データを格納するエリア
    ///加速度の生データ配列(xyz)
    NSMutableArray *acceleration;
    ///加速度の平均化したデータ配列
    NSMutableArray *averageArray;
    
    ///音データ(scratch_forward.wav)
    AVAudioPlayer *scratch_forward;
    ///音データ(scratch_back.wav)
    AVAudioPlayer *scratch_back;
    ///音データ(taiko.wav)
    AVAudioPlayer *taiko;
    ///音データ(asore.wav)
    AVAudioPlayer *asore;
    ///音データ(iinee.wav)
    AVAudioPlayer *iinee;
    ///音データ(iyo.wav)
    AVAudioPlayer *iyo;
    ///音データ(iyoiyo.wav)
    AVAudioPlayer *iyoiyo;
    ///布団たたき時に叩いていない画像に戻すためのタイマー
    NSTimer *offImageTimer;
}

@property (weak, nonatomic) IBOutlet UILabel *label1;
@property (weak, nonatomic) IBOutlet UILabel *label2;
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UISegmentedControl *modeSegment;
@property (weak, nonatomic) IBOutlet UISwitch *stateSwitch;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    //スリープ禁止
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    
    //初期化
    acceleration = [[NSMutableArray alloc] init];
    averageArray = [[NSMutableArray alloc] init];
    self.label1.text = @"disconnected";
    self.label2.text = @"";
    self.stateSwitch.on = NO;
    
    //音の設定
    {
        NSString *path = [[NSBundle mainBundle] pathForResource:@"scratch_forward" ofType:@"wav"];
        NSURL *url = [NSURL fileURLWithPath:path];
        scratch_forward = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:nil];
    }
    {
        NSString *path = [[NSBundle mainBundle] pathForResource:@"scratch_back" ofType:@"wav"];
        NSURL *url = [NSURL fileURLWithPath:path];
        scratch_back = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:nil];
    }
    {
        NSString *path = [[NSBundle mainBundle] pathForResource:@"taiko" ofType:@"wav"];
        NSURL *url = [NSURL fileURLWithPath:path];
        taiko = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:nil];
    }
    ///
    {
        NSString *path = [[NSBundle mainBundle] pathForResource:@"asore" ofType:@"wav"];
        NSURL *url = [NSURL fileURLWithPath:path];
        asore = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:nil];
    }
    {
        NSString *path = [[NSBundle mainBundle] pathForResource:@"iinee" ofType:@"wav"];
        NSURL *url = [NSURL fileURLWithPath:path];
        iinee = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:nil];
    }
    {
        NSString *path = [[NSBundle mainBundle] pathForResource:@"iyo" ofType:@"wav"];
        NSURL *url = [NSURL fileURLWithPath:path];
        iyo = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:nil];
    }
    {
        NSString *path = [[NSBundle mainBundle] pathForResource:@"iyoiyo" ofType:@"wav"];
        NSURL *url = [NSURL fileURLWithPath:path];
        iyoiyo = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:nil];
    }
    
    // CoreBluetoothManagerの初期化
    manager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];

    // Bluetoothスキャン
    [self deviceScan];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    //スリープ有効
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    
    TRACE(@"end");
}
#pragma mark - BLE
// ------------------------------------------------------------------------
//  BLEstate
//
//  Bluetoothが使用できるか状態を確認
// ------------------------------------------------------------------------
- (BOOL)BLEstate {
    
    // 状態判定
    switch ([manager state]) {
            
        case CBCentralManagerStateUnsupported:
            NSLog(@"The platform/hardware doesn't support Bluetooth Low Energy.");
            return false;
            
        case CBCentralManagerStateUnauthorized:
            NSLog(@"The app is not authorized to use Bluetooth Low Energy.");
            return false;
            
        case CBCentralManagerStatePoweredOff:
            NSLog( @"Bluetooth setting -> OFF no");
            return false;
            
        case CBCentralManagerStatePoweredOn:
            NSLog( @"Bluetooth is available to use.");
            return true;
            
        case CBCentralManagerStateUnknown:
            
        default:
            NSLog( @"Bluetooth manager start.");
            return false;
    }
}

// ------------------------------------------------------------------------
//  deviceScan
//
//  Bluetoothのスキャン処理
// ------------------------------------------------------------------------
- (void)deviceScan {
    
    // Bluetoothの状態が正常の場合
    if ([self BLEstate]) {
        
        // 一度スキャンを停止する
        [manager stopScan];
        
        // サービス設定
        NSArray *services = [NSArray arrayWithObjects:[CBUUID UUIDWithString:SENSOR_SERVICE_UUID], nil];
        
        // オプション設定
        NSDictionary *option = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO]forKey:CBCentralManagerScanOptionAllowDuplicatesKey];
        
        // Bluetoothスキャン開始
        [manager scanForPeripheralsWithServices:services options:option];
        
        NSLog(@"scan");
    }
}

// ------------------------------------------------------------------------
//  cleanup
//
//  各設定の初期化
// ------------------------------------------------------------------------
- (void)cleanup {
    
    // デバイス設定のリセット
    if (device) {
        
        device.delegate = nil;
        device = nil;
    }
    
    // ログファイルを閉じる
    [self closeFile];
    
    NSLog(@"cleanup");
    
    // Bluetoothスキャン
    [self deviceScan];
}


#pragma mark - BLE Notifycation
// ------------------------------------------------------------------------
//  centralManagerDidUpdateState
//
//  CBCentralManagerの状態変化後の処理
// ------------------------------------------------------------------------
- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    
    // 状態判定
    switch (central.state) {
            
        case CBCentralManagerStatePoweredOn:
            NSLog(@"centralManagerDidUpdateState poweredOn");
            [self deviceScan];
            break;
            
        case CBCentralManagerStatePoweredOff:
            NSLog(@"centralManagerDidUpdateState poweredOff");
            [self cleanup];
            break;
            
        case CBCentralManagerStateResetting:
            NSLog(@"centralManagerDidUpdateState resetting");
            [self cleanup];
            break;
            
        case CBCentralManagerStateUnauthorized:
            NSLog(@"centralManagerDidUpdateState unauthorized");
            [self cleanup];
            break;
            
        case CBCentralManagerStateUnsupported:
            NSLog(@"centralManagerDidUpdateState unsupported");
            [self cleanup];
            break;
            
        case CBCentralManagerStateUnknown:
            NSLog(@"centralManagerDidUpdateState unknown");
            [self cleanup];
            break;
            
        default:
            break;
    }
}

// ------------------------------------------------------------------------
//  centralManager(didDiscoverPeripheral)
//
//  Bluetoothスキャン時の処理
// ------------------------------------------------------------------------
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)aPeripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
    
    //　advertisementDataのサービスを取得
    NSArray *services = [advertisementData objectForKey:@"kCBAdvDataServiceUUIDs"];
    
    // 設定したサービスと一致した場合
    if ([services containsObject:[CBUUID UUIDWithString:SENSOR_SERVICE_UUID]]) {
        
        // スキャンしたデバイス名を取得
        NSString* findName = [advertisementData objectForKey:CBAdvertisementDataLocalNameKey];
        
        // 設定したデバイス名(DEVICE_NAME)のみ接続
        // （センサーが変わる場合、先頭行のdefineで定義されているDEVICE_NAMEの文字を変更してください）
        if ([findName isEqualToString:DEVICE_NAME]) {
            
            // Bluetoothスキャン停止
            [manager stopScan];
            
            // デバイス設定
            device = aPeripheral;
            
            // オプション設定
            NSDictionary *option = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:CBConnectPeripheralOptionNotifyOnConnectionKey];
            
            // Bluetooth接続処理の開始
            [manager connectPeripheral:device options:option];
            NSLog(@"didDiscoverPeripheral:%@", findName);
        }
    }
}

// ------------------------------------------------------------------------
//  setNotifyValueForService
//
//  Notifyの設定
// ------------------------------------------------------------------------
- (void)setNotifyValueForService:(NSString*)serviceUUIDStr characteristicUUID:(NSString*)characteristicUUIDStr peripheral:(CBPeripheral *)aPeripheral enable:(bool)enable {
    
    CBUUID *serviceUUID = [CBUUID UUIDWithString:serviceUUIDStr];
    CBUUID *characteristicUUID = [CBUUID UUIDWithString:characteristicUUIDStr];
    
    // サービス取得
    CBService *service = [self findServiceFromUUID:serviceUUID peripheral:aPeripheral];
    
    if (!service) {
        
        NSLog(@"Could not find service with UUID %@", serviceUUIDStr);
        return;
    }
    
    // キャラクタリスティック取得
    CBCharacteristic *characteristic = [self findCharacteristicFromUUID:characteristicUUID service:service];
    
    if (!characteristic) {
        
        NSLog(@"Could not find characteristic with UUID %@ on service with UUID %@ ", characteristicUUIDStr, serviceUUIDStr);
        return;
    }
    
    for (characteristic in service.characteristics) {
        
        // キャラクタリスティックUUIDが一致し、Notifyが現在の状態から変更される場合
        if ([characteristic.UUID isEqual:characteristicUUID] && enable != characteristic.isNotifying) {
            
            // Notify設定
            [aPeripheral setNotifyValue:enable forCharacteristic:characteristic];
            
            if (enable) NSLog(@"notifyOn");
            else if (enable) NSLog(@"notifyOff");
        }
    }
}

// ------------------------------------------------------------------------
//  findServiceFromUUID
//
//  Serviceの検索
// ------------------------------------------------------------------------
- (CBService *) findServiceFromUUID:(CBUUID *)UUID peripheral:(CBPeripheral *)aPeripheral {
    
    for (int i = 0; i < aPeripheral.services.count; i++) {
        
        CBService *service = [aPeripheral.services objectAtIndex:i];
        if ([UUID isEqual:service.UUID]) return service;
    }
    
    return nil;
}

// ------------------------------------------------------------------------
//  findCharacteristicFromUUID
//
//  Characteristicの検索
// ------------------------------------------------------------------------
- (CBCharacteristic *) findCharacteristicFromUUID:(CBUUID *)UUID service:(CBService*)service {
    
    for (int i = 0; i < service.characteristics.count; i++) {
        
        CBCharacteristic *characteristic = [service.characteristics objectAtIndex:i];
        if ([UUID isEqual:characteristic.UUID]) return characteristic;
    }
    
    return nil;
}

// ------------------------------------------------------------------------
//  peripheral(didDiscoverServices)
//
//  Service検索完了後の処理
// ------------------------------------------------------------------------
- (void)peripheral:(CBPeripheral *)aPeripheral didDiscoverServices:(NSError *)error {
    
    if (error) {
        
        NSLog(@"Error discovering services: %@", [error localizedDescription]);
        return;
    }
    
    for (CBService *aService in aPeripheral.services) {
        
        // 設定したサービスと一致した場合
        if ([aService.UUID isEqual:[CBUUID UUIDWithString:SENSOR_SERVICE_UUID]]) {
            
            // キャラクタリスティックの検索を開始
            [aPeripheral discoverCharacteristics:nil forService:aService];
        }
    }
}

// ------------------------------------------------------------------------
//  peripheral(didDiscoverCharacteristicsForService)
//
//  Characteristics検索完了後の処理
// ------------------------------------------------------------------------
- (void)peripheral:(CBPeripheral *)aPeripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    
    if (error) {
        
        NSLog(@"chara error : %@", [error localizedDescription]);
        return;
    }
    
    // 設定したサービスと一致した場合
    if ([service.UUID isEqual:[CBUUID UUIDWithString:SENSOR_SERVICE_UUID]]) {
        
        for (CBCharacteristic *aChar in service.characteristics) {
            
            // 設定したキャラクタリスティックと一致した場合
            if ([aChar.UUID isEqual:[CBUUID UUIDWithString:SENSOR_CHARACTERISTIC_UUID]]) {
                
                // Notify有効化
                [self setNotifyValueForService:SENSOR_SERVICE_UUID characteristicUUID:SENSOR_CHARACTERISTIC_UUID peripheral:device enable:YES];
                
                // ログファイル作成
                [self createFile];
            }
        }
    }
}

// ------------------------------------------------------------------------
//  centralManager(didConnectPeripheral)
//
//  Bluetooth接続後の処理
// ------------------------------------------------------------------------
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)aPeripheral {
    
    NSLog(@"connected");
    
    // デリゲート設定
    [device setDelegate:self];
    
    NSArray *services = [NSArray arrayWithObjects:[CBUUID UUIDWithString:SENSOR_SERVICE_UUID], nil];
    
    // サービス検索
    [device discoverServices:services];
}

// ------------------------------------------------------------------------
//  centralManager(didDisconnectPeripheral)
//
//  Bluetooth切断後の処理
// ------------------------------------------------------------------------
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)aPeripheral error:(NSError *)error {
    
    NSLog(@"disConnected");
    
    [self cleanup];
}

// ------------------------------------------------------------------------
//  centralManager(didFailToConnectPeripheral)
//
//  Bluetooth接続失敗時の処理
// ------------------------------------------------------------------------
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)aPeripheral error:(NSError *)error {
    
    NSLog(@"FailToConnected");
    
    [self cleanup];
}

// ------------------------------------------------------------------------
//  peripheral(didUpdateValueForCharacteristic)
//
//  Bluetoothデータ更新時の処理
// ------------------------------------------------------------------------
- (void)peripheral:(CBPeripheral *)aPeripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    
    if (error) {
        
        NSLog(@"didUpdateValueForCharacteristic error: %@", error.localizedDescription);
        return;
    }
    
    // 設定したキャラクタリスティックと一致し、長さが１以上の場合
    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:SENSOR_CHARACTERISTIC_UUID]] && characteristic.value.length > 0) {
        
        // 受信したデータを配列に代入
        UInt8 *dat = (UInt8*) [characteristic.value bytes];
        
        // 以下、データ処理部分（受信するデータのフォーマットに応じて変更）-----------------------------------
        
        // ヘッダーチェック
        if (dat[0] != 0x14) return;
        
        // データチェック
        if ((dat[2]+dat[3]+dat[4]+dat[5]+dat[6]+dat[7]) != 0) {
            
            // 地磁気
            SInt16 rawMx = (dat[3] << 8) | dat[2];
            SInt16 rawMy = (dat[5] << 8) | dat[4];
            SInt16 rawMz = (dat[7] << 8) | dat[6];
            
            // 値制限
            if (rawMx > 16000) rawMx = 16000;
            else if (rawMx < -16000) rawMx = -16000;
            if (rawMy > 16000) rawMy = 16000;
            else if (rawMy < -16000) rawMy = -16000;
            if (rawMz > 16000) rawMz = 16000;
            else if (rawMz < -16000) rawMz = -16000;
            
            datMx = (float)rawMx * 0.15f;
            datMy = (float)rawMy * 0.15f;
            datMz = (float)rawMz * 0.15f;
            
            // 四捨五入
            datMx = roundf(datMx);
            datMy = roundf(datMy);
            datMz = roundf(datMz);
            
            //「-0.0」を「0.0」にする
            if (!datMx) datMx = 0;
            if (!datMy) datMy = 0;
            if (!datMz) datMz = 0;
            
            // 加速度
            SInt16 rawAx = (dat[9] << 8) | dat[8];
            SInt16 rawAy = (dat[11] << 8) | dat[10];
            SInt16 rawAz = (dat[13] << 8) | dat[12];
            
            // 値制限
            if (rawAx > 8191) rawAx = 8191;
            else if (rawAx < -8192) rawAx = -8192;
            if (rawAy > 8191) rawAy = 8191;
            else if (rawAy < -8192) rawAy = -8192;
            if (rawAz > 8191) rawAz = 8191;
            else if (rawAz < -8192) rawAz = -8192;
            
            datAx = (float)rawAx / 1024.0f;
            datAy = (float)rawAy / 1024.0f;
            datAz = (float)rawAz / 1024.0f;
            
            // 小数点第ニ位を四捨五入
            datAx *= 10.0f;
            datAy *= 10.0f;
            datAz *= 10.0f;
            
            datAx = roundf(datAx);
            datAy = roundf(datAy);
            datAz = roundf(datAz);
            
            datAx /= 10.0f;
            datAy /= 10.0f;
            datAz /= 10.0f;
            
            //「-0.0」を「0.0」にする
            if (!datAx) datAx = 0;
            if (!datAy) datAy = 0;
            if (!datAz) datAz = 0;
        }
        
        if (dat[1] == 0xb0) {
            
            // UV・照度
            SInt16 rawUv = (dat[17] << 8) | dat[16];
            SInt16 rawLx = (dat[19] << 8) | dat[18];
            
            // 値制限
            if (rawUv > 4095) rawUv = 4095;
            else if (rawUv < 0) rawUv = 0;
            if (rawLx > 4095) rawLx = 4095;
            else if (rawLx < 0) rawLx = 0;
            
            datUv = (float)rawUv / 200.0f;
            datLx = (float)rawLx * 20.0f;
            
            // 小数点第三位を四捨五入
            datUv *= 100.0f;
            
            datUv = roundf(datUv);
            
            datUv /= 100.0f;
            
            // 四捨五入
            datLx = roundf(datLx);
            
            //「-0.0」を「0.0」にする
            if (!datUv) datUv = 0;
            if (!datLx) datLx = 0;
        }
        else if (dat[1] == 0xb1) {
            
            // 湿度・温度
            SInt16 rawHm = (dat[17] << 8) | dat[16];
            SInt16 rawTm = (dat[19] << 8) | dat[18];
            
            // 値制限
            if (rawHm > 7296) rawHm = 7296;
            else if (rawHm < 896) rawHm = 896;
            if (rawTm > 6346) rawTm = 6346;
            else if (rawTm < 96) rawTm = 96;
            
            datHm = ((float)rawHm - 896.0f) / 64.0f;
            datTm = ((float)rawTm - 2096.0f) / 50.0f;
            
            // 小数点第ニ位を四捨五入
            datHm *= 10.0f;
            datTm *= 10.0f;
            
            datHm = roundf(datHm);
            datTm = roundf(datTm);
            
            datHm /= 10.0f;
            datTm /= 10.0f;
            
            //「-0.0」を「0.0」にする
            if (!datHm) datHm = 0;
            if (!datTm) datTm = 0;
        }
        
        // 気圧
        UInt16 rawPs = (dat[15] << 8) | dat[14];
        
        // 値制限
        if (rawPs > 64773) rawPs = 64773;
        else if (rawPs < 3810) rawPs = 3810;
        
        datPs =  ((float)rawPs * 860.0f) / 65535.0f + 250.0f;
        
        // 小数点第三位を四捨五入
        datPs *= 100.0f;
        
        datPs = roundf(datPs);
        
        datPs /= 100.0f;
        
        // ログデータ書き込み処理
        [self LogOutput];
        
        // データ処理終了-----------------------------------------------------------------------------------
    }
}

#pragma mark - File Control
-(void)createFile
{
    self.label1.text = @"connected";
    self.label2.text = @"";
    self.stateSwitch.on = YES;
    [acceleration removeAllObjects];
    [averageArray removeAllObjects];
}

-(void)closeFile
{
    self.label1.text = @"disconnected";
    self.label2.text = @"";
    self.stateSwitch.on = NO;
    [acceleration removeAllObjects];
    [averageArray removeAllObjects];
}

#pragma mark - Analyze
-(void)LogOutput
{
    //TRACE(@"%@",[NSString stringWithFormat:@"%4.1f, %4.1f, %4.1f",datAx, datAy, datAz]);
    
    ///各方向(xyz)の角速度の値を平均化するためのサンプル数
    int max_array = 5;
    ///平均化した加速度を保持するサンプル数
    int max_array2 = 5;
    
    //乱数
    int ransu = rand()%30 + 1;
    
    //センサーの加速度を格納する
    {
        NSDictionary *dictinary = [NSDictionary dictionaryWithObjectsAndKeys:
                                   [NSNumber numberWithFloat:datAx]    ,   key_acc_x,
                                   [NSNumber numberWithFloat:datAy]    ,   key_acc_y,
                                   [NSNumber numberWithFloat:datAz]    ,   key_acc_z,
                                   nil];
        [acceleration addObject:dictinary];
    }
    
    if ([acceleration count] > max_array) {
        //平均化するための加速度のサンプル数が基準に達した
        //初期化
        ///平均加速度(x)
        float acceleration_value_x = 0;
        ///平均加速度(y)
        float acceleration_value_y = 0;
        ///平均加速度(z)
        float acceleration_value_z = 0;
        for (NSDictionary *item in acceleration) {
            //実際の加速度を加算する
            acceleration_value_x += [[item objectForKey:key_acc_x] floatValue];
            acceleration_value_y += [[item objectForKey:key_acc_y] floatValue];
            acceleration_value_z += [[item objectForKey:key_acc_z] floatValue];
        }
        
        //加算した値を割って、平均値を求める
        acceleration_value_x = acceleration_value_x / (float)[acceleration count];
        acceleration_value_y = acceleration_value_y / (float)[acceleration count];
        acceleration_value_z = acceleration_value_z / (float)[acceleration count];
        
        //平均化加速度(y軸)を保持する
        NSDictionary *dictinary = [NSDictionary dictionaryWithObjectsAndKeys:
                                   [NSNumber numberWithFloat:acceleration_value_x]    ,   key_acc_x,
                                   [NSNumber numberWithFloat:acceleration_value_y]    ,   key_acc_y,
                                   [NSNumber numberWithFloat:acceleration_value_z]    ,   key_acc_z,
                                   nil];

        [averageArray addObject:dictinary];
        
        //規定数格納されているので１つ減らす
        [acceleration removeObjectAtIndex:0];
    }
    if ([averageArray count] > max_array2) {
        //平均化加速度(y軸)をサンプル数が基準に達した
        //加速度の差分を求める
        float diff_value = [[[averageArray objectAtIndex:0] objectForKey:key_acc_y] floatValue] - [[[averageArray lastObject] objectForKey:key_acc_y] floatValue];
        [averageArray removeObjectAtIndex:0];
        //上下を判定するためのスレッシュ値の絶対値
        float diff_thred_abs = 1.0f;
        
        //上下かを判定する
        if (diff_value > diff_thred_abs) {
            self.label1.text = @"上";
            if (self.modeSegment.selectedSegmentIndex == 0) {
                if (ransu == 3) {
                    self.imageView.image = [UIImage imageNamed:@"Yoshida_2.png"];
                    [asore play];
                } else {
                    self.imageView.image = [UIImage imageNamed:@"arai_01.png"];
                    [scratch_forward play];
                }
            }
        } else if (diff_value < (diff_thred_abs * -1.0f)) {
            self.label1.text = @"下";
            if (self.modeSegment.selectedSegmentIndex == 0) {
                if (ransu == 3) {
                    self.imageView.image = [UIImage imageNamed:@"Yoshida_2.png"];
                    [iinee play];
                } else {
                    self.imageView.image = [UIImage imageNamed:@"arai_02.png"];
                    [scratch_back play];
                }
            }
        } else {
            //処理なし
        }
        //TRACE(@"%4.1f",diff_value);
    }
    {
        //タップ判定
        ///平均加速度(x)
        float acceleration_value_x = [[[averageArray lastObject] objectForKey:key_acc_x] floatValue];
        ///平均加速度(y)
        float acceleration_value_y = [[[averageArray lastObject] objectForKey:key_acc_y] floatValue];
        ///平均加速度(z)
        float acceleration_value_z = [[[averageArray lastObject] objectForKey:key_acc_z] floatValue];
        ///加速度の和
        float acceleration_value_total = sqrt((acceleration_value_x * acceleration_value_x) + (acceleration_value_y * acceleration_value_y) + (acceleration_value_z * acceleration_value_z));
        ///タップの閾値
        float tap_thred_abs = 1.2f;
        
        self.label2.text = @"";
        if (acceleration_value_total > tap_thred_abs) {
            self.label2.text = @"タップ";
            if (self.modeSegment.selectedSegmentIndex == 1) {
                //元の画像に戻すタイマースタート
                [offImageTimer invalidate];
                offImageTimer = [NSTimer scheduledTimerWithTimeInterval:0.2f target:self selector:@selector(tataku_02_int:) userInfo:nil repeats:YES];

                //音
                if (ransu == 3) {
                    self.imageView.image = [UIImage imageNamed:@"Yoshida_1.png"];
                    [iyo play];
                } else {
                    self.imageView.image = [UIImage imageNamed:@"tataku_01.png"];
                    [taiko play];
                }
            }
        } else {
            //無処理
        }
    }
}

-(void)tataku_02_int:(NSTimer*)timer{
    if (self.modeSegment.selectedSegmentIndex == 1) {
        self.imageView.image = [UIImage imageNamed:@"tataku_02.png"];
    }
}

#pragma mark - UI Action
- (IBAction)selectAction:(id)sender {
    
    if (self.modeSegment.selectedSegmentIndex == 0) {
        self.imageView.image = [UIImage imageNamed:@"arai_01.png"];
    }
    if (self.modeSegment.selectedSegmentIndex == 1) {
        self.imageView.image = [UIImage imageNamed:@"tataku_02.png"];
    }
    
}


@end
