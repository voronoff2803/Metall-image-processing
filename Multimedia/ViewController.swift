//
//  ViewController.swift
//  Multimedia
//
//  Created by Alexey Voronov on 14/04/2019.
//  Copyright © 2019 Alexey Voronov. All rights reserved.
//

import UIKit
import MetalKit
import Photos

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, FilterSettingsTableViewControllerDelegate {
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    let filterNames = ["grayscale_filter", "empty_filter", "red_filter", "green_filter", "blue_filter", "difference_filter", "combine_filter", "robast_filter", "grayworld_filter", "noise_filter", "median_filter", "gaussian_filter", "gaussian_avg_filter", "gaussian_shift_filter", "gaussian_sharp_filter", "overlay_filter", "gaussian_blur_filter"]
    var selectedFilter: FilterView?
    var segmented = UISegmentedControl()
    var cellHeight: Int = 275
    var scrollView: UIScrollView = UIScrollView()
    var image = UIImage(named: "test")!.imageWithSize(size: CGSize(width: 450, height: 300))
    var filters: [FilterView] = []
    var selectedParam: Int = 0
    var width: Int {
        get {
            return Int(UIScreen.main.bounds.width)
        }
    }
    
    var height: Int {
        get {
            return Int(UIScreen.main.bounds.height)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        switch UIDevice.current.userInterfaceIdiom {
        case .pad:
            cellHeight = 505
        case .phone:
            cellHeight = 275
        case .tv:
            cellHeight = 275
        case .carPlay:
            cellHeight = 275
        @unknown default:
            cellHeight = 275
        }
        
        setup()
        setupButtons()
        setupSegmented()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        showFilters()
    }

    
    func createFilters1() {
        let grayscaleFilter = FilterView(image: image, kernelName: "grayscale_filter")
        filters.append(grayscaleFilter)
        
        let robastFilter = RobastFilterView(parentFilter: grayscaleFilter, kernelName: "robast_filter")
        filters.append(robastFilter)
        
        addFilterToChain(kernelName: "difference_filter")
    }
    
    func createFilters2() {
        let emptyFilter = FilterView(image: image, kernelName: "empty_filter")
        emptyFilter.info = "Исходное изображение"
        filters.append(emptyFilter)

        let redFilter = FilterView(parentFilter: emptyFilter, kernelName: "red_filter")
        redFilter.info = "Красный канал"
        filters.append(redFilter)

        let robastFilterRed = RobastFilterView(parentFilter: redFilter, kernelName: "robast_filter")
        robastFilterRed.info = "Красный канал линейно растяyтый"
        robastFilterRed.parentFilter = redFilter
        filters.append(robastFilterRed)

        let greenFilter = FilterView(parentFilter: emptyFilter, kernelName: "green_filter")
        greenFilter.info = "Зеленый канал"
        filters.append(greenFilter)

        let robastFilterGreen = RobastFilterView(parentFilter: greenFilter, kernelName: "robast_filter")
        robastFilterGreen.info = "Зеленый канал линейно растянутый"
        robastFilterGreen.parentFilter = greenFilter
        filters.append(robastFilterGreen)

        let blueFilter = FilterView(parentFilter: emptyFilter, kernelName: "blue_filter")
        blueFilter.info = "Синий канал"
        filters.append(blueFilter)

        let robastFilterBlue = RobastFilterView(parentFilter: blueFilter, kernelName: "robast_filter")
        robastFilterBlue.info = "Синий канал линейно растянутый"
        robastFilterBlue.parentFilter = blueFilter
        filters.append(robastFilterBlue)

        let combineFilter = FilterView(parentFilter: robastFilterRed, kernelName: "combine_filter")
        combineFilter.info = "Объединенные линейно растянутые каналы"
        combineFilter.parentFilter2 = robastFilterGreen
        combineFilter.parentFilter3 = robastFilterBlue
        filters.append(combineFilter)

        let grayworldFilter = GrayWorldFilterView(parentFilter: redFilter, kernelName: "grayworld_filter")
        grayworldFilter.info = "Cерый мир для начального изображения"
        grayworldFilter.parentFilter2 = greenFilter
        grayworldFilter.parentFilter3 = blueFilter
        grayworldFilter.parentFilter4 = emptyFilter
        filters.append(grayworldFilter)
    }

    func createFilters3() {
        let emptyFilter = FilterView(image: image, kernelName: "empty_filter")
        filters.append(emptyFilter)

        let noiseFilter = FilterView(parentFilter: emptyFilter, kernelName: "noise_filter")
        noiseFilter.info = "шум типа «соль и перец»"
        filters.append(noiseFilter)

        let differenceFilter = FilterView(parentFilter: noiseFilter, kernelName: "difference_filter")
        differenceFilter.parentFilter2 = emptyFilter
        differenceFilter.info = "карта разницы между исходным и зашумленным изображениями"
        filters.append(differenceFilter)

        let medianFilter = FilterView(parentFilter: noiseFilter, kernelName: "median_filter")
        medianFilter.info = "подавление шума медианным фильтром"
        filters.append(medianFilter)

        let differenceFilter2 = FilterView(parentFilter: medianFilter, kernelName: "difference_filter")
        differenceFilter2.info = "карта разницы между скорректированным и исходным"
        differenceFilter2.parentFilter2 = emptyFilter
        filters.append(differenceFilter2)
    }

    func createFilters4() {
        let emptyFilter = FilterView(image: image, kernelName: "empty_filter")
        filters.append(emptyFilter)
        
        let gaussianFilter2 = FilterView(parentFilter: emptyFilter, kernelName: "gaussian_avg_filter")
        filters.append(gaussianFilter2)
        
        let differenceFilter = FilterView(parentFilter: emptyFilter, kernelName: "difference_filter")
        differenceFilter.parentFilter2 = gaussianFilter2
        filters.append(differenceFilter)
        
        let gaussianFilter3 = FilterView(parentFilter: emptyFilter, kernelName: "gaussian_shift_filter")
        filters.append(gaussianFilter3)
        
        let differenceFilter2 = FilterView(parentFilter: emptyFilter, kernelName: "difference_filter")
        differenceFilter2.parentFilter2 = gaussianFilter3
        filters.append(differenceFilter2)
        
        let gaussianFilter4 = FilterView(parentFilter: emptyFilter, kernelName: "gaussian_sharp_filter")
        filters.append(gaussianFilter4)
        
        let differenceFilter3 = FilterView(parentFilter: emptyFilter, kernelName: "difference_filter")
        differenceFilter3.parentFilter2 = gaussianFilter4
        filters.append(differenceFilter3)
    }
    
    func createFilters5() {
        let emptyFilter = FilterView(image: image, kernelName: "empty_filter")
        filters.append(emptyFilter)
        
        let gaussianFilter = FilterView(parentFilter: emptyFilter, kernelName: "gaussian_blur_filter")
        filters.append(gaussianFilter)
        
        let differenceclipFilter = FilterView(parentFilter: emptyFilter, kernelName: "differenceclip_filter")
        differenceclipFilter.parentFilter2 = gaussianFilter
        filters.append(differenceclipFilter)
        
        let overlayFilter = FilterView(parentFilter: emptyFilter, kernelName: "overlay_filter")
        overlayFilter.parentFilter2 = differenceclipFilter
        filters.append(overlayFilter)
    }
    
    func createEmptyFilters() {
        let emptyFilter = FilterView(image: image, kernelName: "empty_filter")
        filters.append(emptyFilter)
    }
    
    func setup() {
        view.backgroundColor = .black
        
        scrollView = UIScrollView(frame: self.view.frame)
        view.addSubview(scrollView)
        
        scrollView.isScrollEnabled = true
        scrollView.bounces = false
        scrollView.showsVerticalScrollIndicator = false
        
        if filters.isEmpty {
            let emptyFilter = FilterView(image: image, kernelName: "empty_filter")
            filters.append(emptyFilter)
        }
    }
    
    func addFilter(name: String) {
        switch name {
        case "robast_filter":
            let robastFilter = RobastFilterView(parentFilter: filters.last!, kernelName: "robast_filter")
            robastFilter.info = "\(filters.count)"
            filters.append(robastFilter)
        case "grayworld_filter":
            let grayworldFilter = GrayWorldFilterView(parentFilter: filters.last!, kernelName: "grayworld_filter")
            grayworldFilter.info = "\(filters.count)"
            filters.append(grayworldFilter)
        default:
            addFilterToChain(kernelName: name)
        }
    }
    
    func setupSegmented() {
        segmented = UISegmentedControl(frame: CGRect(x: 0, y: 0, width: width, height: 25))
        segmented.tintColor = .white
        segmented.insertSegment(withTitle: "№1", at: 0, animated: false)
        segmented.insertSegment(withTitle: "№2", at: 1, animated: false)
        segmented.insertSegment(withTitle: "№3", at: 2, animated: false)
        segmented.insertSegment(withTitle: "№4", at: 3, animated: false)
        segmented.insertSegment(withTitle: "№5", at: 4, animated: false)
        segmented.insertSegment(withTitle: "очистить", at: 5, animated: false)
        segmented.addTarget(self, action: #selector(changeTask), for: .valueChanged)
        self.view.addSubview(segmented)
    }
    
    @objc func changeTask() {
        switch segmented.selectedSegmentIndex {
        case 0:
            filters.removeAll()
            createFilters1()
            showFilters()
        case 1:
            filters.removeAll()
            createFilters2()
            showFilters()
        case 2:
            filters.removeAll()
            createFilters3()
            showFilters()
        case 3:
            filters.removeAll()
            createFilters4()
            showFilters()
        case 4:
            filters.removeAll()
            createFilters5()
            showFilters()
        case 5:
            filters.removeAll()
            createEmptyFilters()
            showFilters()
        default:
            filters.removeAll()
            createEmptyFilters()
            showFilters()
        }
    }
    
    func setupButtons() {
        let reloadButton = UIButton(frame: CGRect(x: 0, y: height - 80, width: width / 2 - 5, height: 35))
        reloadButton.setTitle("Reload", for: .normal)
        reloadButton.setTitleColor(.white, for: .normal)
        reloadButton.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        reloadButton.addTarget(self, action: #selector(reload), for: .touchUpInside)
        reloadButton.layer.cornerRadius = 8
        view.addSubview(reloadButton)
        
        let loadImageButton = UIButton(frame: CGRect(x: width / 2 + 5, y: height - 80, width: width / 2 - 5, height: 35))
        loadImageButton.setTitle("Open img", for: .normal)
        loadImageButton.setTitleColor(.white, for: .normal)
        loadImageButton.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        loadImageButton.addTarget(self, action: #selector(reloadImage), for: .touchUpInside)
        loadImageButton.layer.cornerRadius = 8
        view.addSubview(loadImageButton)
        
        let addFilterButton = UIButton(frame: CGRect(x: 0, y: height - 120, width: width / 2 - 5, height: 35))
        addFilterButton.setTitle("Add filter", for: .normal)
        addFilterButton.setTitleColor(.white, for: .normal)
        addFilterButton.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        addFilterButton.addTarget(self, action: #selector(showFilterAddTable), for: .touchUpInside)
        addFilterButton.layer.cornerRadius = 8
        view.addSubview(addFilterButton)
    }
    
    @objc func showFilterAddTable() {
        let tableViewController = FilterSettingsTableViewController()
        tableViewController.data = filterNames
        tableViewController.usingForIndex = 2
        tableViewController.delegate = self
        navigationController?.pushViewController(tableViewController, animated: true)
    }
    
    func setupImagePicker() {
        checkPermission()
        let imagePicker = UIImagePickerController()
        imagePicker.modalPresentationStyle = UIModalPresentationStyle.currentContext
        imagePicker.delegate = self
        self.present(imagePicker, animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]){
        let tempImage = info[UIImagePickerController.InfoKey.originalImage] as! UIImage
        image = tempImage.imageWithSize(size: CGSize(width: 600, height: 450))
        
        self.dismiss(animated: true, completion: nil)
        
        reload()
    }
    
    private func imagePickerControllerDidCancel(picker: UIImagePickerController!) {
        self.dismiss(animated: true, completion: nil)
    }
    
    func checkPermission() {
        let photoAuthorizationStatus = PHPhotoLibrary.authorizationStatus()
        switch photoAuthorizationStatus {
        case .authorized:
            print("Access is granted by user")
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization({
                (newStatus) in
                print("status is \(newStatus)")
                if newStatus ==  PHAuthorizationStatus.authorized {
                    /* do stuff here */
                    print("success")
                }
            })
            print("It is not determined until now")
        case .restricted:
            // same same
            print("User do not have access to photo album.")
        case .denied:
            // same same
            print("User has denied the permission.")
        }
    }
    
    func addFilterToChain(kernelName: String) {
        let filterView = FilterView(parentFilter: filters[filters.count - 1], kernelName: kernelName)
        filterView.info = "\(filters.count)"
        if filters.count > 1 {
            filterView.parentFilter2 = filters[filters.count - 2]
        }
        filters.append(filterView)
    }
    
    func showFilters() {
        scrollView.subviews.forEach({$0.removeFromSuperview()})
        for (index, filterView) in filters.enumerated() {
            let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.selectFilter(_:)))
            let holdRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(self.deleteFilter(_:)))
            holdRecognizer.minimumPressDuration = 1.6
            filterView.addGestureRecognizer(tapRecognizer)
            filterView.addGestureRecognizer(holdRecognizer)
            filterView.layer.masksToBounds = true
            filterView.layer.cornerRadius = 16
            filterView.frame = CGRect(x: 0, y: index * (cellHeight + 5) + 30, width: width, height: cellHeight)
            scrollView.addSubview(filterView)
            filterView.processImage()
        }
        scrollView.contentSize = CGSize(width: width, height: filters.count * (cellHeight + 5) + 150)
    }
    
    @objc func selectFilter(_ sender: UITapGestureRecognizer? = nil) {
        selectedFilter = (sender?.view as! FilterView)
        let tableViewController = FilterSettingsTableViewController()
        tableViewController.data = selectedFilter!.parametrs
        tableViewController.usingForIndex = 0
        tableViewController.filter = sender?.view as! FilterView
        tableViewController.delegate = self
        navigationController?.pushViewController(tableViewController, animated: true)
        
    }
    
    @objc func deleteFilter(_ sender: UITapGestureRecognizer? = nil) {
        if filters.count > 1 {
            
            selectedFilter = (sender?.view as! FilterView)
            print(selectedFilter)
            let index = filters.firstIndex(of: selectedFilter!)
            if index != nil && index != 0 {
                filters.remove(at: index!)
                showFilters()
            }
            showFilters()
        }
    }
    
    func selectItem(index: Int, usingForIndex: Int) {
        if usingForIndex == 0 {
            selectedParam = index
            let tableViewController = FilterSettingsTableViewController()
            tableViewController.data = filters.map({$0.kernelName + " | " + $0.info})
            tableViewController.usingForIndex = 1
            tableViewController.delegate = self
            navigationController?.pushViewController(tableViewController, animated: true)
        } else if usingForIndex == 1 {
            
            switch selectedParam {
            case 0:
                selectedFilter?.parentFilter = filters[index]
            case 1:
                selectedFilter?.parentFilter2 = filters[index]
            case 2:
                selectedFilter?.parentFilter3 = filters[index]
            case 3:
                selectedFilter?.parentFilter4 = filters[index]
            default:
                print("switch wrong case!")
            }
            reload()
            
        } else if usingForIndex == 2 {
            addFilter(name: filterNames[index])
            showFilters()
        }
    }
    
    @objc func reloadImage() {
        setupImagePicker()
    }
    
    @objc func reload() {
        self.filters.first?.loadUIImage(uiimage: self.image)
        for filter in self.filters {
            filter.processImage()
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        
        print("touches ended")
    }
}

