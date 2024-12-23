//
//  BarcodeReader.swift
//  VinylPredictor
//
//  Created by Bradley Cable on 02/11/2024.
//

import SwiftUI
import CarBode
import AVFoundation
import Combine

final class BarcodeViewDataStorage: ObservableObject, Observable {
    @Published var path: NavigationPath = NavigationPath()
    @Published var barcodeScanResult: Album?
}


struct BarcodeReader: View {
    
    @EnvironmentObject private var viewParameters: ViewParameters
    
    @EnvironmentObject var barcodeViewData: BarcodeViewDataStorage
    @State private var scanningErrorAlert = false
    
    var body: some View {
        
        VStack {
            Text("Scan Vinyl Barcode")
                .font(.title)
                .bold()
                .padding()
            
            // taken from the libraries example page, and then modified
            CBScanner(
                supportBarcode: .constant([.upce, .ean8, .ean13, .code39, .code128, .code93]),
                scanInterval: .constant(3) // Attempted scanning will trigger every 3 seconds
            ){
                // When the scanner found a barcode
                let valueOfBarcode = $0.value
                print("Value of barcode: ", valueOfBarcode)
                
                // search Discogs database
                Task {
                    if case .success(let album) = await searchDiscogs(barcode: valueOfBarcode) {
                        
                        if album.isEmpty != true {
                            let foundAlbum = album.first!
                            print(foundAlbum.title, foundAlbum.id)
                            
                            barcodeViewData.barcodeScanResult = foundAlbum
                            barcodeViewData.path.append("DetailAlbumView")
                        } else {
                            print("No albums found with that barcode")
                            scanningErrorAlert.toggle()
                        }
                    } else {
                        print("error searching discogs")
                        scanningErrorAlert.toggle()
                    }
                }
            }
            // draws box around barcode
            onDraw: {
                //line width
                let lineWidth = 2.0
                
                //line color
                let lineColor = UIColor.red
                
                let fillColor = UIColor(red: 0, green: 1, blue: 0.2, alpha: 0.4)
                
                //Draw box
                $0.draw(lineWidth: lineWidth, lineColor: lineColor, fillColor: fillColor)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding()
        .alert(isPresented: $scanningErrorAlert) {
            Alert(
                title: Text("Error scanning the barcode shown!"),
                message: Text("Please try again, or search manually by name."),
                dismissButton: .default(Text("Got it!")))
        }
    
    }
}

//#Preview {
//    @Previewable @State var isShowingBarcodeSheet: Bool = false
//    
//    Group {
//        Button("Show Sheet") {
//            isShowingBarcodeSheet.toggle()
//        }
//    }
//    .sheet(isPresented: $isShowingBarcodeSheet, content: {
//        BarcodeReaderSheet()
//    })
//}
