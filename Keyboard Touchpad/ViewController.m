//
//  ViewController.m
//  ios-bluetooth-test
//
//  Created by Pedro Lucas on 27/09/16.
//  Copyright © 2016 Pedro. All rights reserved.
//

#import "ViewController.h"
#import <CoreBluetooth/CoreBluetooth.h>

#define kServiceUUID [CBUUID UUIDWithString:@"b0d0"]
#define kCharacteristicsUUID [CBUUID UUIDWithString:@"b0d1"]

@interface ViewController () <CBCentralManagerDelegate, CBPeripheralDelegate>

@property (nonatomic, strong) CBCentralManager *centralManager;
@property (nonatomic, strong) CBPeripheral *discoveredPeripheral;
@property (nonatomic, strong) CBService *discoveredService;
@property (nonatomic, strong) CBCharacteristic *discoveredCharacteristic;

@property (weak, nonatomic) IBOutlet UIButton *btnSendData;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:dispatch_get_main_queue()];
}

#pragma mark - Private

- (void)startScan {
    if(![self.centralManager isScanning]) {
        [self stopDiscover];
        [self.centralManager scanForPeripheralsWithServices:@[kServiceUUID] options:@{CBCentralManagerScanOptionAllowDuplicatesKey: @NO}];
    }
}

- (void)stopDiscover {
    if([self.centralManager isScanning]) {
        [self.centralManager stopScan];
    }
    [self.discoveredPeripheral setDelegate:nil];
    [self setDiscoveredPeripheral:nil];
    [self setDiscoveredService:nil];
    [self setDiscoveredCharacteristic:nil];
    [self.btnSendData setEnabled:NO];
}

#pragma mark - CBCentralManagerDelegate

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    if (central.state != CBCentralManagerStatePoweredOn) {
        [self stopDiscover];
        return;
    }
    [self startScan];
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    NSLog(@"didDiscoverPeripheral: %@", peripheral.name);
    if(self.discoveredPeripheral != peripheral) {
        [self setDiscoveredPeripheral:peripheral];
        [self.centralManager connectPeripheral:self.discoveredPeripheral options:nil];
        [self.centralManager stopScan];
    }
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    NSLog(@"Peripheral didConnectPeripheral");
    [self.discoveredPeripheral setDelegate:self];
    [self.discoveredPeripheral readRSSI];
    [self.discoveredPeripheral discoverServices:@[kServiceUUID]];
}

- (void)peripheralDidUpdateRSSI:(CBPeripheral *)peripheral error:(nullable NSError *)error {
    if (error) {
        NSLog(@"Error peripheralDidUpdateRSSI: %@", [error localizedDescription]);
        return;
    }else{
        NSLog(@"peripheralDidUpdateRSSI");
    }
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error {
    NSLog(@"Peripheral didFailToConnectPeripheral");
    [self startScan];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"Peripheral Disconnected");
    [self startScan];
}

#pragma mark - CBPeripheralDelegate

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if (error) {
        NSLog(@"Error discovering services: %@", [error localizedDescription]);
        return;
    }else{
        NSLog(@"didDiscoverServices");
        [[self.discoveredPeripheral services] enumerateObjectsUsingBlock:^(CBService * _Nonnull service, NSUInteger idx, BOOL * _Nonnull stop) {
            if([service.UUID.UUIDString isEqualToString:kServiceUUID.UUIDString]) {
                [self setDiscoveredService:service];
                [self.discoveredPeripheral discoverCharacteristics:@[kCharacteristicsUUID] forService:service];
                *stop = YES;
            }
        }];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    if (error) {
        NSLog(@"Error discovering characteristics: %@", [error localizedDescription]);
        return;
    }else{
        NSLog(@"didDiscoverCharacteristicsForService");
        [self.discoveredService.characteristics enumerateObjectsUsingBlock:^(CBCharacteristic * _Nonnull characteristic, NSUInteger idx, BOOL * _Nonnull stop) {
            if([characteristic.UUID.UUIDString isEqualToString:kCharacteristicsUUID.UUIDString]) {
                [self setDiscoveredCharacteristic:characteristic];
                [self.discoveredPeripheral setNotifyValue:YES forCharacteristic:self.discoveredCharacteristic];
                [self.discoveredCharacteristic.descriptors enumerateObjectsUsingBlock:^(CBDescriptor * _Nonnull descriptor, NSUInteger idx, BOOL * _Nonnull stop) {
                    [self.discoveredPeripheral readValueForDescriptor:descriptor];
                }];
                *stop = YES;
            }
        }];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForDescriptor:(CBDescriptor *)descriptor error:(nullable NSError *)error {
    if (error) {
        NSLog(@"Error didUpdateValueForDescriptor: %@", [error localizedDescription]);
        return;
    }else{
        NSLog(@"didUpdateValueForDescriptor: %@", [descriptor value]);
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error {
    if (error) {
        NSLog(@"Error didUpdateNotificationStateForCharacteristic: %@", [error localizedDescription]);
        return;
    }else{
        [self.btnSendData setEnabled:YES];
        NSLog(@"didUpdateNotificationStateForCharacteristic");
    }
}

#pragma mark - IBAction

- (IBAction)sendData {
    NSData *send = [NSJSONSerialization dataWithJSONObject:@{@"type": @"mouse", @"data": @{
                                                                        @"x": @10,
                                                                        @"y": @20
                                                                     }} options:0 error:nil];
    
    [self.discoveredPeripheral writeValue:send forCharacteristic:self.discoveredCharacteristic type:CBCharacteristicWriteWithoutResponse];
}

- (IBAction)reloadConnection:(UIButton *)sender {
    [self stopDiscover];
    [self startScan];
}

/*
 - (void)peripheral:(CBPeripheral *)peripheral didDiscoverDescriptorsForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error {
 if (error) {
 NSLog(@"Error discovering descriptor: %@", [error localizedDescription]);
 return;
 }else{
 NSLog(@"didDiscoverDescriptorsForCharacteristic");
 [self.discoveredCharacteristic.descriptors enumerateObjectsUsingBlock:^(CBDescriptor * _Nonnull descriptor, NSUInteger idx, BOOL * _Nonnull stop) {
 NSLog(@"Descriptor: %@", [descriptor description]);
 }];
 }
 }
 */



@end
