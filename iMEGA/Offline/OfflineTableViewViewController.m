
#import "OfflineTableViewViewController.h"

#import "NSString+MNZCategory.h"
#import "UIImageView+MNZCategory.h"

#import "Helper.h"
#import "MEGAStore.h"

#import "OfflineTableViewCell.h"
#import "OfflineViewController.h"

static NSString *kFileName = @"kFileName";
static NSString *kPath = @"kPath";

@interface OfflineTableViewViewController () <MGSwipeTableCellDelegate, UITableViewDataSource, UITableViewDelegate>

@end

@implementation OfflineTableViewViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.tableView.contentOffset = CGPointMake(0, CGRectGetHeight(self.offline.searchController.searchBar.frame));
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
}

#pragma mark - Public

- (void)tableViewSelectIndexPath:(NSIndexPath *)indexPath {
    [self tableView:self.tableView didSelectRowAtIndexPath:indexPath];
}

- (void)setTableViewEditing:(BOOL)editing animated:(BOOL)animated {
    [self.tableView setEditing:editing animated:animated];
    
    [self.offline setViewEditing:editing];
    
    if (editing) {
        for (OfflineTableViewCell *cell in self.tableView.visibleCells) {
            UIView *view = [[UIView alloc] init];
            view.backgroundColor = UIColor.clearColor;
            cell.selectedBackgroundView = view;
        }
    } else {
        for (OfflineTableViewCell *cell in self.tableView.visibleCells) {
            cell.selectedBackgroundView = nil;
        }
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger rows = self.offline.searchController.isActive ? self.offline.searchItemsArray.count : self.offline.offlineSortedItems.count;
    [self.offline enableButtonsByNumberOfItems];
    return rows;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    OfflineTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"offlineTableViewCell" forIndexPath:indexPath];
    
    NSString *directoryPathString = [self.offline currentOfflinePath];
    NSString *nameString = [[self.offline itemAtIndexPath:indexPath] objectForKey:kFileName];
    NSString *pathForItem = [directoryPathString stringByAppendingPathComponent:nameString];
    
    cell.itemNameString = nameString;
    
    MOOfflineNode *offNode = [[MEGAStore shareInstance] fetchOfflineNodeWithPath:[Helper pathRelativeToOfflineDirectory:pathForItem]];
    NSString *handleString = offNode.base64Handle;
    
    cell.thumbnailPlayImageView.hidden = YES;
    
    BOOL isDirectory;
    [[NSFileManager defaultManager] fileExistsAtPath:pathForItem isDirectory:&isDirectory];
    if (isDirectory) {
        cell.thumbnailImageView.image = [Helper folderImage];
        
        NSInteger files = 0;
        NSInteger folders = 0;
        
        NSArray *directoryContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:pathForItem error:nil];
        for (NSString *file in directoryContents) {
            BOOL isDirectory;
            NSString *path = [pathForItem stringByAppendingPathComponent:file];
            if (![path.pathExtension.lowercaseString isEqualToString:@"mega"]) {
                [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory];
                isDirectory ? folders++ : files++;
            }
            
        }
        
        cell.infoLabel.text = [NSString mnz_stringByFiles:files andFolders:folders];
    } else {
        NSString *extension = nameString.pathExtension.lowercaseString;
        
        if (!handleString) {
            NSString *fpLocal = [[MEGASdkManager sharedMEGASdk] fingerprintForFilePath:pathForItem];
            if (fpLocal) {
                MEGANode *node = [[MEGASdkManager sharedMEGASdk] nodeForFingerprint:fpLocal];
                if (node) {
                    handleString = node.base64Handle;
                    [[MEGAStore shareInstance] insertOfflineNode:node api:[MEGASdkManager sharedMEGASdk] path:[[Helper pathRelativeToOfflineDirectory:pathForItem] decomposedStringWithCanonicalMapping]];
                }
            }
        }
        
        NSString *thumbnailFilePath = [Helper pathForSharedSandboxCacheDirectory:@"thumbnailsV3"];
        thumbnailFilePath = [thumbnailFilePath stringByAppendingPathComponent:handleString];
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:thumbnailFilePath] && handleString) {
            UIImage *thumbnailImage = [UIImage imageWithContentsOfFile:thumbnailFilePath];
            if (thumbnailImage) {
                [cell.thumbnailImageView setImage:thumbnailImage];
                if (nameString.mnz_isVideoPathExtension) {
                    cell.thumbnailPlayImageView.hidden = NO;
                }
            }
            
        } else {
            if (nameString.mnz_isImagePathExtension) {
                if (![[NSFileManager defaultManager] fileExistsAtPath:thumbnailFilePath]) {
                    [[MEGASdkManager sharedMEGASdk] createThumbnail:pathForItem destinatioPath:thumbnailFilePath];
                }
            } else {
                [cell.thumbnailImageView mnz_setImageForExtension:extension];
            }
        }
        
        NSDictionary *filePropertiesDictionary = [[NSFileManager defaultManager] attributesOfItemAtPath:pathForItem error:nil];
        
        time_t rawtime = [[filePropertiesDictionary valueForKey:NSFileModificationDate] timeIntervalSince1970];
        NSString *date = [Helper dateWithISO8601FormatOfRawTime:rawtime];
        
        unsigned long long size;
        size = [[[NSFileManager defaultManager] attributesOfItemAtPath:pathForItem error:nil] fileSize];
        
        NSString *sizeString = [NSByteCountFormatter stringFromByteCount:size countStyle:NSByteCountFormatterCountStyleMemory];
        NSString *sizeAndDate = [NSString stringWithFormat:@"%@ • %@", sizeString, date];
        cell.infoLabel.text = sizeAndDate;
    }
    cell.nameLabel.text = [[MEGASdkManager sharedMEGASdk] unescapeFsIncompatible:nameString];
    
    if (self.tableView.isEditing) {
        for (NSURL *url in self.offline.selectedItems) {
            if ([url.path isEqualToString:pathForItem]) {
                [self.tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
            }
        }
        
        UIView *view = [[UIView alloc] init];
        view.backgroundColor = UIColor.clearColor;
        cell.selectedBackgroundView = view;
    }
    
    if (@available(iOS 11.0, *)) {
        cell.thumbnailImageView.accessibilityIgnoresInvertColors = YES;
        cell.thumbnailPlayImageView.accessibilityIgnoresInvertColors = YES;
    } else {
        cell.delegate = self;
    }
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (tableView.isEditing) {
        NSURL *filePathURL = [[self.offline itemAtIndexPath:indexPath] objectForKey:kPath];
        [self.offline.selectedItems addObject:filePathURL];
        
        [self.offline updateNavigationBarTitle];
        [self.offline enableButtonsBySelectedItems];
        
        self.offline.allItemsSelected = (self.offline.selectedItems.count == self.offline.offlineSortedItems.count);
        
        return;
    }
    
    OfflineTableViewCell *cell = (OfflineTableViewCell *)[tableView cellForRowAtIndexPath:indexPath];
    [self.offline itemTapped:cell.nameLabel.text atIndexPath:indexPath];
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (tableView.isEditing) {
        NSURL *filePathURL = [[self.offline itemAtIndexPath:indexPath] objectForKey:kPath];
        
        NSMutableArray *tempArray = self.offline.selectedItems.copy;
        for (NSURL *url in tempArray) {
            if ([url.filePathURL isEqual:filePathURL]) {
                [self.offline.selectedItems removeObject:url];
            }
        }
        
        [self.offline updateNavigationBarTitle];
        [self.offline enableButtonsBySelectedItems];
        
        self.offline.allItemsSelected = NO;
        
        return;
    }
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    UIContextualAction *deleteAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:@"Share" handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        OfflineTableViewCell *cell = (OfflineTableViewCell *)[tableView cellForRowAtIndexPath:indexPath];
        NSString *itemPath = [[self.offline currentOfflinePath] stringByAppendingPathComponent:cell.itemNameString];
        [self.offline removeOfflineNodeCell:itemPath];
    }];
    deleteAction.image = [UIImage imageNamed:@"delete"];
    deleteAction.backgroundColor = [UIColor colorWithRed:0.94 green:0.22 blue:0.23 alpha:1];
    return [UISwipeActionsConfiguration configurationWithActions:@[deleteAction]];
}

#pragma clang diagnostic pop

#pragma mark - MGSwipeTableCellDelegate

- (BOOL)swipeTableCell:(MGSwipeTableCell *)cell canSwipe:(MGSwipeDirection)direction fromPoint:(CGPoint)point {
    if (self.tableView.isEditing) {
        return NO;
    }
    
    if (direction == MGSwipeDirectionLeftToRight) {
        return NO;
    }
    
    return YES;
}

- (NSArray *)swipeTableCell:(MGSwipeTableCell *)cell swipeButtonsForDirection:(MGSwipeDirection)direction swipeSettings:(MGSwipeSettings *)swipeSettings expansionSettings:(MGSwipeExpansionSettings *)expansionSettings {
    
    swipeSettings.transition = MGSwipeTransitionDrag;
    expansionSettings.buttonIndex = 0;
    expansionSettings.expansionLayout = MGSwipeExpansionLayoutCenter;
    expansionSettings.fillOnTrigger = NO;
    expansionSettings.threshold = 2;
    
    if (direction == MGSwipeDirectionRightToLeft) {
        
        MGSwipeButton *deleteButton = [MGSwipeButton buttonWithTitle:@"" icon:[UIImage imageNamed:@"delete"] backgroundColor:[UIColor colorWithRed:0.93 green:0.22 blue:0.23 alpha:1.0] padding:25 callback:^BOOL(MGSwipeTableCell *sender) {
            OfflineTableViewCell *offlineCell = (OfflineTableViewCell *)cell;
            NSString *itemPath = [self.offline.currentOfflinePath stringByAppendingPathComponent:offlineCell.itemNameString];
            [self.offline removeOfflineNodeCell:itemPath];
            
            return YES;
        }];
        [deleteButton iconTintColor:[UIColor whiteColor]];
        
        return @[deleteButton];
    }
    else {
        return nil;
    }
}

@end
