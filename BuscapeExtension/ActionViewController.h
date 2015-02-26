//
//  ActionViewController.h
//  BuscapeExtension
//
//  Created by Lucas Moreira on 22/02/15.
//  Copyright (c) 2015 Lucas Santos. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ActionViewController : UITableViewController {
    BOOL isRequestingProductID;
}

@property (nonatomic, strong) NSString *productName;

@property (nonatomic, strong) NSMutableData *responseData;
@property (nonatomic, strong) NSMutableArray *offers;

@end
