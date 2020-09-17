//
//  ViewController.m
//  LinkMap
//
//  Created by Suteki(67111677@qq.com) on 4/8/16.
//  Copyright © 2016 Apple. All rights reserved.
//

#import "ViewController.h"
#import "SymbolModel.h"

@interface ViewController()

@property (weak) IBOutlet NSTextField *filePathField;//显示选择的文件路径
@property (weak) IBOutlet NSProgressIndicator *indicator;//指示器
@property (weak) IBOutlet NSTextField *searchField;

@property (weak) IBOutlet NSScrollView *contentView;//分析的内容
@property (unsafe_unretained) IBOutlet NSTextView *contentTextView;
@property (weak) IBOutlet NSButton *groupButton;


@property (strong) NSURL *linkMapFileURL;
@property (strong) NSString *linkMapContent;

@property (strong) NSMutableString *result;//分析的结果

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.indicator.hidden = YES;
    
    _contentTextView.editable = NO;
    
    _contentTextView.string = @"使用方式：\n\
    1.在XCode中开启编译选项Write Link Map File \n\
    XCode -> Project -> Build Settings -> 把Write Link Map File选项设为yes，并指定好linkMap的存储位置 \n\
    2.工程编译完成后，在编译目录里找到Link Map文件（txt类型） \n\
    默认的文件地址：~/Library/Developer/Xcode/DerivedData/XXX-xxxxxxxxxxxxx/Build/Intermediates/XXX.build/Debug-iphoneos/XXX.build/ \n\
    3.回到本应用，点击“选择文件”，打开Link Map文件  \n\
    4.点击“开始”，解析Link Map文件 \n\
    5.点击“输出文件”，得到解析后的Link Map文件 \n\
    6. * 输入目标文件的关键字(例如：libIM)，然后点击“开始”。实现搜索功能 \n\
    7. * 勾选“分组解析”，然后点击“开始”。实现对不同库的目标文件进行分组";
}

- (IBAction)chooseFile:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.allowsMultipleSelection = NO;
    panel.canChooseDirectories = NO;
    panel.resolvesAliases = NO;
    panel.canChooseFiles = YES;
    
    [panel beginWithCompletionHandler:^(NSInteger result){
        if (result == NSFileHandlingPanelOKButton) {
            NSURL *document = [[panel URLs] objectAtIndex:0];
            _filePathField.stringValue = document.path;
            self.linkMapFileURL = document;
        }
    }];
}

- (IBAction)analyze:(id)sender {
    if (!_linkMapFileURL || ![[NSFileManager defaultManager] fileExistsAtPath:[_linkMapFileURL path] isDirectory:nil]) {
        [self showAlertWithText:@"请选择正确的Link Map文件路径"];
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        /// 读取link-map文件信息
        NSString *content = [NSString stringWithContentsOfURL:_linkMapFileURL encoding:NSMacOSRomanStringEncoding error:nil];
        
        if (![self checkContent:content]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showAlertWithText:@"Link Map文件格式有误"];
            });
            return ;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.indicator.hidden = NO;
            [self.indicator startAnimation:self];
            
        });
        
        /// 获取所有的symbols模型
        NSDictionary *symbolMap = [self symbolMapFromContent:content];
        
        NSArray <SymbolModel *>*symbols = [symbolMap allValues];
        
        /// 降序排列
        NSArray *sortedSymbols = [self sortSymbols:symbols];
        
        __block NSControlStateValue groupButtonState;
        dispatch_sync(dispatch_get_main_queue(), ^{
            groupButtonState = _groupButton.state;
        });
        
        if (1 == groupButtonState) {
            [self buildCombinationResultWithSymbols:sortedSymbols];
        } else {
            [self buildResultWithSymbols:sortedSymbols];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.contentTextView.string = _result;
            self.indicator.hidden = YES;
            [self.indicator stopAnimation:self];
            
        });
    });
}

- (NSMutableDictionary *)symbolMapFromContent:(NSString *)content {
    
    NSMutableDictionary <NSString *,SymbolModel *>*symbolMap = [NSMutableDictionary new];
    
    // 符号文件列表 : 使用换行符切割成字符串数组
    NSArray *lines = [content componentsSeparatedByString:@"\n"]; /// 用换行符切割
    
    /**
     "# Path: /Users/tiny/Library/Developer/Xcode/DerivedData/CoreData-biampcxablpiutfebmedptlcrueb/Build/Products/Debug-iphonesimulator/CoreData.app/CoreData",
     "# Arch: x86_64",
     "# Object files:",
     "[  0] linker synthesized",
     "[  1] /Users/tiny/Library/Developer/Xcode/DerivedData/CoreData-biampcxablpiutfebmedptlcrueb/Build/Intermediates.noindex/CoreData.build/Debug-iphonesimulator/CoreData.build/CoreData.app-Simulated.xcent",
     "[  2] /Users/tiny/Library/Developer/Xcode/DerivedData/CoreData-biampcxablpiutfebmedptlcrueb/Build/Intermediates.noindex/CoreData.build/Debug-iphonesimulator/CoreData.build/Objects-normal/x86_64/ViewController.o",
     "[  3] /Users/tiny/Library/Developer/Xcode/DerivedData/CoreData-biampcxablpiutfebmedptlcrueb/Build/Intermediates.noindex/CoreData.build/Debug-iphonesimulator/CoreData.build/Objects-normal/x86_64/CoreDataStore.o",
     "[  4] /Users/tiny/Library/Developer/Xcode/DerivedData/CoreData-biampcxablpiutfebmedptlcrueb/Build/Intermediates.noindex/CoreData.build/Debug-iphonesimulator/CoreData.build/Objects-normal/x86_64/DataManager.o",
     "[  5] /Users/tiny/Library/Developer/Xcode/DerivedData/CoreData-biampcxablpiutfebmedptlcrueb/Build/Intermediates.noindex/CoreData.build/Debug-iphonesimulator/CoreData.build/Objects-normal/x86_64/AppDelegate.o",
     "[  6] /Users/tiny/Library/Developer/Xcode/DerivedData/CoreData-biampcxablpiutfebmedptlcrueb/Build/Intermediates.noindex/CoreData.build/Debug-iphonesimulator/CoreData.build/Objects-normal/x86_64/main.o",
     "[  7] /Users/tiny/Library/Developer/Xcode/DerivedData/CoreData-biampcxablpiutfebmedptlcrueb/Build/Intermediates.noindex/CoreData.build/Debug-iphonesimulator/CoreData.build/Objects-normal/x86_64/SceneDelegate.o",
     "[  8] /Applications/Xcode11.5.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator13.5.sdk/System/Library/Frameworks//Foundation.framework/Foundation.tbd",
     "[  9] /Applications/Xcode11.5.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator13.5.sdk/usr/lib/libobjc.tbd",
     "[ 10] /Applications/Xcode11.5.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator13.5.sdk/usr/lib/libSystem.tbd",
     "[ 11] /Applications/Xcode11.5.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator13.5.sdk/System/Library/Frameworks//UIKit.framework/UIKit.tbd",
     "# Sections:",
     "# Address\tSize    \tSegment\tSection",
     "0x100001160\t0x00001B23\t__TEXT\t__text",
     "0x100002C84\t0x0000007E\t__TEXT\t__stubs",
     "0x100002D04\t0x000000E2\t__TEXT\t__stub_helper",
     "0x100002DE6\t0x00001183\t__TEXT\t__objc_methname",
     "0x100003F69\t0x00000091\t__TEXT\t__objc_classname",
     "0x100003FFA\t0x00000B49\t__TEXT\t__objc_methtype",
     "0x100004B43\t0x000002BF\t__TEXT\t__cstring",
     "0x100004E02\t0x00000034\t__TEXT\t__ustring",
     "0x100004E36\t0x00000174\t__TEXT\t__entitlements",
     "0x100004FAC\t0x00000048\t__TEXT\t__unwind_info",
     "0x100005000\t0x00000038\t__DATA_CONST\t__got",
     "0x100005038\t0x00000030\t__DATA_CONST\t__const",
     "0x100005068\t0x00000240\t__DATA_CONST\t__cfstring",
     "0x1000052A8\t0x00000028\t__DATA_CONST\t__objc_classlist",
     "0x1000052D0\t0x00000020\t__DATA_CONST\t__objc_protolist",
     "0x1000052F0\t0x00000008\t__DATA_CONST\t__objc_imageinfo",
     "0x100006000\t0x000000A8\t__DATA\t__la_symbol_ptr",
     "0x1000060A8\t0x00001890\t__DATA\t__objc_const",
     "0x100007938\t0x00000138\t__DATA\t__objc_selrefs",
     "0x100007A70\t0x00000070\t__DATA\t__objc_classrefs",
     "0x100007AE0\t0x00000010\t__DATA\t__objc_superrefs",
     "0x100007AF0\t0x00000048\t__DATA\t__objc_ivar",
     "0x100007B38\t0x00000190\t__DATA\t__objc_data",
     "0x100007CC8\t0x00000188\t__DATA\t__data",
     "0x100007E50\t0x00000010\t__DATA\t__bss",
     "# Symbols:",
     "# Address\tSize    \tFile  Name",
     "0x100001160\t0x00000040\t[  2] -[ViewController viewDidLoad]",
     "0x1000011A0\t0x00000070\t[  2] -[ViewController setupContext:]",
     "0x100001210\t0x00000080\t[  2] -[ViewController update:]",
     "0x100001290\t0x00000040\t[  2] -[ViewController delete:]",
     "0x1000012D0\t0x00000080\t[  2] -[ViewController fetch:]",
     "0x100001350\t0x00000040\t[  2] -[ViewController setUpContextBtn]",
     "0x100001390\t0x00000040\t[  2] -[ViewController setSetUpContextBtn:]",
     "0x1000013D0\t0x00000040\t[  2] -[ViewController updateBtn]",
     "0x100001410\t0x00000040\t[  2] -[ViewController setUpdateBtn:]",
     "0x100001450\t0x00000040\t[  2] -[ViewController deleteBtn]",
     "0x100001490\t0x00000040\t[  2] -[ViewController setDeleteBtn:]",
     "0x1000014D0\t0x00000040\t[  2] -[ViewController fetchBtn]",
     "0x100001510\t0x00000040\t[  2] -[ViewController setFetchBtn:]"
     ....
     */
    
    BOOL reachFiles = NO;
    BOOL reachSymbols = NO;
    BOOL reachSections = NO;
    
    for(NSString *line in lines) {
        if([line hasPrefix:@"#"]) {
            if([line hasPrefix:@"# Object files:"])
                reachFiles = YES;
            else if ([line hasPrefix:@"# Sections:"])
                reachSections = YES;
            else if ([line hasPrefix:@"# Symbols:"])
                reachSymbols = YES;
        } else {
            if(reachFiles == YES && reachSections == NO && reachSymbols == NO) {
                /// 解析 Object files: 部分
                NSRange range = [line rangeOfString:@"]"];
                if(range.location != NSNotFound) {
                    SymbolModel *symbol = [SymbolModel new];
                    symbol.file = [line substringFromIndex:range.location+1]; /// 符号所属文件路径
                    NSString *key = [line substringToIndex:range.location+1]; /// 文件的类型标识符，在link-map文件中以 [ 0]、[ 1]标识
                    symbolMap[key] = symbol;
                }
            } else if (reachFiles == YES && reachSections == YES && reachSymbols == YES) {
                /// 解析 Symbols: 部分
                NSArray <NSString *>*symbolsArray = [line componentsSeparatedByString:@"\t"];
                /// 使用制表符切割 "# Address\tSize    \tFile  Name"
                /// 如 "0x100001160\t0x00000040\t[  2] -[ViewController viewDidLoad]",

                
                if(symbolsArray.count == 3) {
                    NSString *fileKeyAndName = symbolsArray[2];
                    // 符号占用的内存大小
                    NSUInteger size = strtoul([symbolsArray[1] UTF8String], nil, 16); /// strtoul将16进制字符串按10进制输出
                    
                    NSRange range = [fileKeyAndName rangeOfString:@"]"];
                    if(range.location != NSNotFound) {
                        NSString *key = [fileKeyAndName substringToIndex:range.location+1];
                        SymbolModel *symbol = symbolMap[key];
                        if(symbol) {
                            symbol.size += size;
                        }
                    }
                }
            }
        }
    }
    return symbolMap;
}

- (NSArray *)sortSymbols:(NSArray *)symbols {
    NSArray *sortedSymbols = [symbols sortedArrayUsingComparator:^NSComparisonResult(SymbolModel *  _Nonnull obj1, SymbolModel *  _Nonnull obj2) {
        if(obj1.size > obj2.size) {
            return NSOrderedAscending;
        } else if (obj1.size < obj2.size) {
            return NSOrderedDescending;
        } else {
            return NSOrderedSame;
        }
    }];
    
    return sortedSymbols;
}

- (void)buildResultWithSymbols:(NSArray *)symbols {
    /**
     '\r'是回车，前者使光标到行首，（carriage return）
     '\n'是换行，后者使光标下移一格，（line feed）
     */
    self.result = [@"文件大小\t文件名称\r\n\r\n" mutableCopy];
    NSUInteger totalSize = 0;
    
    __block NSString *searchKey;
    dispatch_sync(dispatch_get_main_queue(), ^{
        searchKey = _searchField.stringValue;
    });

    
    for(SymbolModel *symbol in symbols) {
        if (searchKey.length > 0) {
            if ([symbol.file containsString:searchKey]) {
                [self appendResultWithSymbol:symbol];
                totalSize += symbol.size;
            }
        } else {
            [self appendResultWithSymbol:symbol];
            totalSize += symbol.size;
        }
    }
    
    [_result appendFormat:@"\r\n总大小: %.2fM\r\n",(totalSize/1024.0/1024.0)];
}


- (void)buildCombinationResultWithSymbols:(NSArray *)symbols {
    self.result = [@"库大小\t库名称\r\n\r\n" mutableCopy];
    NSUInteger totalSize = 0;
    
    NSMutableDictionary *combinationMap = [[NSMutableDictionary alloc] init];
    
    for(SymbolModel *symbol in symbols) {
        NSString *name = [[symbol.file componentsSeparatedByString:@"/"] lastObject];
        if ([name hasSuffix:@")"] &&
            [name containsString:@"("]) {
            NSRange range = [name rangeOfString:@"("];
            NSString *component = [name substringToIndex:range.location];
            
            SymbolModel *combinationSymbol = [combinationMap objectForKey:component];
            if (!combinationSymbol) {
                combinationSymbol = [[SymbolModel alloc] init];
                [combinationMap setObject:combinationSymbol forKey:component];
            }
            
            combinationSymbol.size += symbol.size;
            combinationSymbol.file = component;
        } else {
            // symbol可能来自app本身的目标文件或者系统的动态库，在最后的结果中一起显示
            [combinationMap setObject:symbol forKey:symbol.file];
        }
    }
    
    NSArray <SymbolModel *>*combinationSymbols = [combinationMap allValues];
    
    NSArray *sortedSymbols = [self sortSymbols:combinationSymbols];
    
    NSString *searchKey = _searchField.stringValue;
    
    for(SymbolModel *symbol in sortedSymbols) {
        if (searchKey.length > 0) {
            if ([symbol.file containsString:searchKey]) {
                [self appendResultWithSymbol:symbol];
                totalSize += symbol.size;
            }
        } else {
            [self appendResultWithSymbol:symbol];
            totalSize += symbol.size;
        }
    }
    
    [_result appendFormat:@"\r\n总大小: %.2fM\r\n",(totalSize/1024.0/1024.0)];
}

- (IBAction)ouputFile:(id)sender {
    NSOpenPanel* panel = [NSOpenPanel openPanel];
    [panel setAllowsMultipleSelection:NO];
    [panel setCanChooseDirectories:YES];
    [panel setResolvesAliases:NO];
    [panel setCanChooseFiles:NO];
    
    [panel beginWithCompletionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            NSURL*  theDoc = [[panel URLs] objectAtIndex:0];
            NSMutableString *content =[[NSMutableString alloc]initWithCapacity:0];
            [content appendString:[theDoc path]];
            [content appendString:@"/linkMap.txt"];
            [_result writeToFile:content atomically:YES encoding:NSUTF8StringEncoding error:nil];
        }
    }];
}

- (void)appendResultWithSymbol:(SymbolModel *)model {
    NSString *size = nil;
    if (model.size / 1024.0 / 1024.0 > 1) {
        size = [NSString stringWithFormat:@"%.2fM", model.size / 1024.0 / 1024.0];
    } else {
        size = [NSString stringWithFormat:@"%.2fK", model.size / 1024.0];
    }
    /// 拼接每个.o文件的带下和文件名称
    [_result appendFormat:@"%@\t%@\r\n",size, [[model.file componentsSeparatedByString:@"/"] lastObject]];
}

- (BOOL)checkContent:(NSString *)content {
    
    NSRange objsFileTagRange = [content rangeOfString:@"# Object files:"];
    
//    NSLog(@"objsFileTagRange: %@", NSStringFromRange(objsFileTagRange));
    
    if (objsFileTagRange.length == 0) {
        return NO;
    }
    NSString *subObjsFileSymbolStr = [content substringFromIndex:objsFileTagRange.location + objsFileTagRange.length];
    
//    NSLog(@"subObjsFileSymbolStr: %@", subObjsFileSymbolStr);

    NSRange symbolsRange = [subObjsFileSymbolStr rangeOfString:@"# Symbols:"];
    
//    NSLog(@"symbolsRange: %@", NSStringFromRange(objsFileTagRange));

    if ([content rangeOfString:@"# Path:"].length <= 0||objsFileTagRange.location == NSNotFound||symbolsRange.location == NSNotFound) {
        return NO;
    }
    return YES;
}

- (void)showAlertWithText:(NSString *)text {
    NSAlert *alert = [[NSAlert alloc]init];
    alert.messageText = text;
    [alert addButtonWithTitle:@"确定"];
    [alert beginSheetModalForWindow:[NSApplication sharedApplication].windows[0] completionHandler:^(NSModalResponse returnCode) {
    }];
}

@end
