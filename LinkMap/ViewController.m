//
//  ViewController.m
//  LinkMap
//
//  Created by Suteki(67111677@qq.com) on 4/8/16.
//  Copyright © 2016 Apple. All rights reserved.
//

#import "ViewController.h"

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

static NSString *kConstPrefix = @"Contents of (__DATA";
static NSString *kQueryClassList = @"__objc_classlist";
static NSString *kQueryClassRefs = @"__objc_classrefs";
static NSString *kQuerySuperRefs = @"__objc_superrefs";

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.indicator.hidden = YES;
    
    _contentTextView.editable = NO;
    
    _contentTextView.string = @"使用方式：\n\
    1.Xcode打包导出ipa，把ipa后缀改为zip，然后解压缩，取出.app中的mach-o文件 \n\
    2.打开 terminal，运行命令：otool -arch arm64 -ov XXX > XXX.txt，其中XXX是mach-o文件的名字 \n\
    3.回到本应用，点击“选择文件”，打开刚刚生成XXX.txt文件  \n\
    4.点击“开始”，解析文件 \n\
    5.点击“输出文件”，得到解析后的文件 \n\
    6. * 勾选“解析方法”，然后点击“开始”。得到的是未使用的方法";
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
        [self showAlertWithText:@"请选择正确的otool文件路径"];
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *content = [NSString stringWithContentsOfURL:_linkMapFileURL encoding:NSMacOSRomanStringEncoding error:nil];
        
        if (![self checkContent:content]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showAlertWithText:@"otool文件格式有误"];
            });
            return ;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.indicator.hidden = NO;
            [self.indicator startAnimation:self];
            
        });
        
        // 所有classList类和类名字
        NSDictionary *classListDic = [self classListFromContent:content];
        // 所有引用的类
        NSArray *classRefs = [self classRefsFromContent:content];
//        // 所有引用的父类
//        NSArray *superRefs = [self superRefsFromContent:content];
        
        // 先把类和父类数组做去重
        NSMutableSet *refsSet = [NSMutableSet setWithArray:classRefs];
//        [refsSet addObjectsFromArray:superRefs];
        
        // 所有在refsSet中的都是已使用的，遍历classList，移除refsSet中涉及的类
        // 余下的就是多余的类
        // 移除系统类，比如SceneDelegate，或者Storyboard中的类
        for (NSString *address in refsSet.allObjects) {
            [classListDic setValue:nil forKey:address];
        }
        
        NSLog(@"多余的类如下：%@", classListDic);
        
        __block NSControlStateValue groupButtonState;
        dispatch_sync(dispatch_get_main_queue(), ^{
            groupButtonState = _groupButton.state;
        });
        
        if (1 == groupButtonState) { // 查找多余的方法

        } else { // 查找多余的类
            [self buildResultWithDictionary:classListDic groupBtnState:groupButtonState];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.contentTextView.string = _result;
            self.indicator.hidden = YES;
            [self.indicator stopAnimation:self];
            
        });
    });
}

// 获取classrefs
- (NSArray *)classRefsFromContent:(NSString *)content {
    // 符号文件列表
    NSArray *lines = [content componentsSeparatedByString:@"\n"];
    
    NSMutableArray *classRefsResults = [NSMutableArray array];

    BOOL classRefsBegin = NO;
    
    for(NSString *line in lines) {
       if ([line containsString:kConstPrefix] && [line containsString:kQueryClassRefs]) {
            classRefsBegin = YES;
            continue;;
        }
        else if (classRefsBegin && [line containsString:kConstPrefix]) {
            classRefsBegin = NO;
            break;
        }
        
        if(classRefsBegin && [line containsString:@"000000010"]) {
            NSArray *components = [line componentsSeparatedByString:@" "];
            NSString *address = [components lastObject];
            if ([address hasPrefix:@"0x100"]) {
                [classRefsResults addObject:address];            }
        }
    }

    NSLog(@"\n\n__objc_refs总结如下，共有%ld个\n%@：", classRefsResults.count, classRefsResults);
    return classRefsResults;
}

// 获取superrefs
- (NSArray *)superRefsFromContent:(NSString *)content {
    // 符号文件列表
    NSArray *lines = [content componentsSeparatedByString:@"\n"];
    
    NSMutableArray *classSuperRefsResults = [NSMutableArray array];

    BOOL classSuperRefsBegin = NO;

    for(NSString *line in lines) {
        if ([line containsString:kConstPrefix] && [line containsString:kQuerySuperRefs]) {
            classSuperRefsBegin = YES;
            continue;;
        }
        else if (classSuperRefsBegin && [line containsString:kConstPrefix]) {
            classSuperRefsBegin = NO;
            break;
        }
        if(classSuperRefsResults && [line containsString:@"000000010"]) {
            NSArray *components = [line componentsSeparatedByString:@" "];
            NSString *address = [components lastObject];
            if ([address hasPrefix:@"0x100"]) {
                [classSuperRefsResults addObject:address];
            }
        }
    }
    NSLog(@"\n\n__objc_superrefs总结如下，共有%ld个\n%@：", classSuperRefsResults.count, classSuperRefsResults);
    return classSuperRefsResults;
}

// 获取classList的类
- (NSMutableDictionary *)classListFromContent:(NSString *)content {
    // 符号文件列表
    NSArray *lines = [content componentsSeparatedByString:@"\n"];
    
    BOOL canAddName = NO;
    
    NSMutableDictionary *classListResults = [NSMutableDictionary dictionary];

    NSString *addressStr = @"";
    BOOL classListBegin = NO;
        
    for(NSString *line in lines) {
        if([line containsString:kConstPrefix] && [line containsString:kQueryClassList]) {
            classListBegin = YES;
            continue;
        }
        else if ([line containsString:kConstPrefix]) {
            classListBegin = NO;
            break;;
        }

        if (classListBegin) {
            if([line containsString:@"000000010"]) {
                NSArray *components = [line componentsSeparatedByString:@" "];
                NSString *address = [components lastObject];
                addressStr = address;
                canAddName = YES;
            }
            else {
                if (classListBegin) {
                    if (canAddName && [line containsString:@"name"]) {
                        NSArray *components = [line componentsSeparatedByString:@" "];
                        NSString *className = [components lastObject];
                        [classListResults setValue:className forKey:addressStr];
                        addressStr = @"";
                        canAddName = NO;
                    }
                }
            }
        }
    }
    NSLog(@"__objc_classlist总结如下，共有%ld个\n%@：", classListResults.count, classListResults);
    return classListResults;
}

- (void)buildResultWithDictionary:(NSDictionary *)targetDic groupBtnState:(NSInteger)groupBtnState {
    if (groupBtnState == 1) {
        self.result = [@"方法地址\t方法名称\r\n\r\n" mutableCopy];
    }
    else {
        self.result = [@"文件地址\t文件名称\r\n\r\n" mutableCopy];
    }
    
    for (NSString *address in targetDic.allKeys) {
        NSString *name = targetDic[address];
        [_result appendFormat:@"%@\t%@\r\n", address, name];
    }
    
    [_result appendFormat:@"\r\n总计: %ld个\r\n", (long)targetDic.count];
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
            
            if (1 == self.groupButton.state) { // 查找多余的方法
                [content appendString:@"/redundantMethod.txt"];
            }
            else {
                [content appendString:@"/redundantClass.txt"];
            }
            [_result writeToFile:content atomically:YES encoding:NSUTF8StringEncoding error:nil];
        }
    }];
}

- (BOOL)checkContent:(NSString *)content {
    NSRange objsFileTagRange = [content rangeOfString:kConstPrefix];
    if (objsFileTagRange.length == 0) {
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
