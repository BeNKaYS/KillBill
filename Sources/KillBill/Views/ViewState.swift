import SwiftUI

// Disambiguates the stable property wrapper from the newer State macro when
// building with Command Line Tools without the SwiftUIMacros plugin.
typealias ViewState<Value> = SwiftUI.State<Value>
