//
//  ActionViewController.m
//  BuscapeExtension
//
//  Created by Lucas Moreira on 22/02/15.
//  Copyright (c) 2015 Lucas Santos. All rights reserved.
//

#import "ActionViewController.h"
#import <MobileCoreServices/MobileCoreServices.h>

@interface ActionViewController ()

@end

@implementation ActionViewController
@synthesize productName, responseData;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationItem.title = @"Carregando...";
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Fechar" style:UIBarButtonItemStylePlain target:self action:@selector(done:)];
    
    BOOL resultFound = NO;
    for (NSExtensionItem *item in self.extensionContext.inputItems) {
        for (NSItemProvider *itemProvider in item.attachments) {
            if ([itemProvider hasItemConformingToTypeIdentifier:(NSString *)kUTTypePropertyList]) {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                    [itemProvider loadItemForTypeIdentifier:(NSString *)kUTTypePropertyList options:nil completionHandler:^(NSDictionary *jsDict, NSError *error) {
                        NSLog(@"jsDict: %@", jsDict);
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            // Get javascript result
                            NSDictionary *results = jsDict[NSExtensionJavaScriptPreprocessingResultsKey];
                            self.productName = [results objectForKey:@"productName"];
                            
                            // Create and share access to an NSUserDefaults object.
                            NSUserDefaults *mySharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.buscapeextension"];
                            
                            // Get history
                            NSMutableArray *mutableHistory = [[mySharedDefaults objectForKey:@"buscapeHistory"] mutableCopy];
                            
                            // Add product to history
                            [mutableHistory addObject:productName];
                            
                            // Use the shared user defaults object to update history.
                            [mySharedDefaults setObject:[mutableHistory copy] forKey:@"buscapeHistory"];
                            [mySharedDefaults synchronize];
                            
                            // Search
                            [self search];
                            
                        });
                        
                    }];
                });
                
                resultFound = YES;
                break;
            }
        }
        
        if (resultFound == YES)
            break;
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}



#pragma mark - Methods

- (void)search {
    NSLog(@"Começando a busca");
    
    isRequestingProductID = YES;
    
    NSString *keywords = [[self.productName stringByReplacingOccurrencesOfString:@" " withString:@"+"] stringByReplacingOccurrencesOfString:@"." withString:@""];
    
    NSString *encodedString = (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)keywords, NULL, (CFStringRef)@"!*'();:@&=+$,/?%#[]", kCFStringEncodingUTF8));
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setHTTPMethod:@"GET"];
    [request setURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://sandbox.buscape.com/service/findProductList/50315056646a38666658673d/?keyword=%@&format=json", encodedString]]];
    
    NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    if (connection)
        self.responseData = [NSMutableData data];
    
    [connection start];
}

- (void)getOffers:(NSString *)productID {
    isRequestingProductID = NO;
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setHTTPMethod:@"GET"];
    [request setURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://sandbox.buscape.com/service/findOfferList/50315056646a38666658673d/?productId=%@&format=json&sort=price", productID]]];
    
    NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    if (connection)
        self.responseData = [NSMutableData data];
    
    [connection start];
}

- (void)done:(id)sender {
    // Return any edited content to the host app.
    // This template doesn't do anything, so we just echo the passed in items.
    // [self.extensionContext completeRequestReturningItems:self.extensionContext.inputItems completionHandler:nil];
    
    NSExtensionItem *extensionItem = [[NSExtensionItem alloc] init];
    extensionItem.attachments = @[[[NSItemProvider alloc] initWithItem:@{ NSExtensionJavaScriptFinalizeArgumentKey: @{ @"bestOffer": self.offers.firstObject } } typeIdentifier:(NSString *)kUTTypePropertyList]];
    
    [self.extensionContext completeRequestReturningItems:@[ extensionItem ] completionHandler:nil];
}



#pragma mark - NSURLConnection delegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    [self.responseData setLength:0];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [self.responseData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    NSError *e;
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:self.responseData options:0 error:&e];
    
    NSLog(@"Result: %@", dict);
    
    if (isRequestingProductID) {
        [self getOffers:dict[@"product"][0][@"product"][@"id"]];
        
    } else {
        self.navigationItem.title = self.productName;
        self.offers = [NSMutableArray array];
        
        for (NSDictionary *offer in dict[@"offer"]) {
            NSString *sellername = offer[@"offer"][@"seller"][@"sellername"];
            NSString *price = [NSString stringWithFormat:@"R$%@", [offer[@"offer"][@"price"][@"value"] stringByReplacingOccurrencesOfString:@"." withString:@","]];

            [self.offers addObject:@{ @"sellername": sellername, @"price": price }];
        }
        
        NSLog(@"Offers: %@", self.offers);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.tableView reloadData];
        });
    }
}



#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.offers.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    
    NSDictionary *dict = self.offers[indexPath.row];
    
    cell.textLabel.text = dict[@"sellername"];
    cell.detailTextLabel.text = dict[@"price"];
    
    return cell;
}

@end
