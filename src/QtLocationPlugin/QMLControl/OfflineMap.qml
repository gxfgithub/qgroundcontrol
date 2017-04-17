/****************************************************************************
 *
 *   (c) 2009-2016 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick                  2.3
import QtQuick.Controls         1.2
import QtQuick.Controls.Styles  1.4
import QtQuick.Dialogs          1.2
import QtQuick.Layouts          1.2
import QtLocation               5.3
import QtPositioning            5.3

import QGroundControl                       1.0
import QGroundControl.Controls              1.0
import QGroundControl.ScreenTools           1.0
import QGroundControl.Palette               1.0
import QGroundControl.FlightMap             1.0
import QGroundControl.QGCMapEngineManager   1.0

QGCView {
    id:             offlineMapView
    viewPanel:      panel
    anchors.fill:   parent

    property var    _currentSelection:  null

    property string mapKey:             "lastMapType"

    property string mapType:            _settings.mapProvider.enumStringValue + " " + _settings.mapType.enumStringValue
    property bool   isMapInteractive:   false
    property var    savedCenter:        undefined
    property real   savedZoom:          3
    property string savedMapType:       ""
    property bool   _showPreview:       true
    property bool   _defaultSet:        offlineMapView && offlineMapView._currentSelection && offlineMapView._currentSelection.defaultSet
    property real   _margins:           ScreenTools.defaultFontPixelWidth * 0.5
    property real   _buttonSize:        ScreenTools.defaultFontPixelWidth * 12
    property real   _bigButtonSize:     ScreenTools.defaultFontPixelWidth * 16

    property bool   _saveRealEstate:          ScreenTools.isTinyScreen || ScreenTools.isShortScreen
    property real   _adjustableFontPointSize: _saveRealEstate ? ScreenTools.smallFontPointSize : ScreenTools.defaultFontPointSize

    property var    _mapAdjustedColor:  _map.isSatelliteMap ? "white" : "black"
    property bool   _tooManyTiles:      QGroundControl.mapEngineManager.tileCount > _maxTilesForDownload
    property var    _settings:          QGroundControl.settingsManager.flightMapSettings

    readonly property real minZoomLevel:    1
    readonly property real maxZoomLevel:    20
    readonly property real sliderTouchArea: ScreenTools.defaultFontPixelWidth * (ScreenTools.isTinyScreen ? 5 : (ScreenTools.isMobile ? 6 : 3))

    readonly property int _maxTilesForDownload: 100000

    QGCPalette { id: qgcPal }

    Component.onCompleted: {
        QGroundControl.mapEngineManager.loadTileSets()
        updateMap()
        savedCenter = _map.toCoordinate(Qt.point(_map.width / 2, _map.height / 2), false /* clipToViewPort */)
    }

    Connections {
        target: QGroundControl.mapEngineManager
        onTileSetsChanged: {
            setName.text = QGroundControl.mapEngineManager.getUniqueName()
        }
        onErrorMessageChanged: {
            errorDialog.visible = true
        }
    }

    ExclusiveGroup { id: setGroup }

    function handleChanges() {
        if(isMapInteractive) {
            var xl = 0
            var yl = 0
            var xr = _map.width.toFixed(0) - 1  // Must be within boundaries of visible map
            var yr = _map.height.toFixed(0) - 1 // Must be within boundaries of visible map
            var c0 = _map.toCoordinate(Qt.point(xl, yl), false /* clipToViewPort */)
            var c1 = _map.toCoordinate(Qt.point(xr, yr), false /* clipToViewPort */)
            QGroundControl.mapEngineManager.updateForCurrentView(c0.longitude, c0.latitude, c1.longitude, c1.latitude, sliderMinZoom.value, sliderMaxZoom.value, mapType)
        }
    }

    function updateMap() {
        for (var i = 0; i < _map.supportedMapTypes.length; i++) {
            if (mapType === _map.supportedMapTypes[i].name) {
                _map.activeMapType = _map.supportedMapTypes[i]
                handleChanges()
                return
            }
        }
    }

    function addNewSet() {
        isMapInteractive = true
        mapType = _settings.mapProvider.enumStringValue + " " + _settings.mapType.enumStringValue
        resetMapToDefaults()
        handleChanges()
        _map.visible = true
        _tileSetList.visible = false
        infoView.visible = false
        _exporTiles.visible = false
        addNewSetView.visible = true
    }

    function showList() {
        _exporTiles.visible = false
        isMapInteractive = false
        _map.visible = false
        _tileSetList.visible = true
        infoView.visible = false
        addNewSetView.visible = false
        QGroundControl.mapEngineManager.resetAction();
    }

    function showExport() {
        isMapInteractive = false
        _map.visible = false
        _tileSetList.visible = false
        infoView.visible = false
        addNewSetView.visible = false
        _exporTiles.visible = true
    }

    function showInfo() {
        isMapInteractive = false
        if(_currentSelection && !offlineMapView._currentSelection.deleting) {
            enterInfoView()
        } else
            showList()
    }

    function toRadian(deg) {
        return deg * Math.PI / 180
    }

    function toDegree(rad) {
        return rad * 180 / Math.PI
    }

    function midPoint(lat1, lat2, lon1, lon2) {
        var dLon = toRadian(lon2 - lon1);
        lat1 = toRadian(lat1);
        lat2 = toRadian(lat2);
        lon1 = toRadian(lon1);
        var Bx = Math.cos(lat2) * Math.cos(dLon);
        var By = Math.cos(lat2) * Math.sin(dLon);
        var lat3 = Math.atan2(Math.sin(lat1) + Math.sin(lat2), Math.sqrt((Math.cos(lat1) + Bx) * (Math.cos(lat1) + Bx) + By * By));
        var lon3 = lon1 + Math.atan2(By, Math.cos(lat1) + Bx);
        return QtPositioning.coordinate(toDegree(lat3), toDegree(lon3))
    }

    function enterInfoView() {
        _map.visible = true
        isMapInteractive = false
        savedCenter = _map.toCoordinate(Qt.point(_map.width / 2, _map.height / 2), false /* clipToViewPort */)
        savedZoom = _map.zoomLevel
        savedMapType = mapType
        if(!offlineMapView._currentSelection.defaultSet) {
            mapType = offlineMapView._currentSelection.mapTypeStr
            _map.center = midPoint(offlineMapView._currentSelection.topleftLat, offlineMapView._currentSelection.bottomRightLat, offlineMapView._currentSelection.topleftLon, offlineMapView._currentSelection.bottomRightLon)
            //-- Delineate Set Region
            var x0 = offlineMapView._currentSelection.topleftLon
            var x1 = offlineMapView._currentSelection.bottomRightLon
            var y0 = offlineMapView._currentSelection.topleftLat
            var y1 = offlineMapView._currentSelection.bottomRightLat
            mapBoundary.topLeft     = QtPositioning.coordinate(y0, x0)
            mapBoundary.bottomRight = QtPositioning.coordinate(y1, x1)
            mapBoundary.visible = true
            // Some times, for whatever reason, the bounding box is correct (around ETH for instance), but the rectangle is drawn across the planet.
            // When that happens, the "_map.fitViewportToMapItems()" below makes the map to zoom to the entire earth.
            //console.log("Map boundary: " + mapBoundary.topLeft + " " + mapBoundary.bottomRight)
            _map.fitViewportToMapItems()
        }
        _tileSetList.visible = false
        addNewSetView.visible = false
        infoView.visible = true
    }

    function leaveInfoView() {
        mapBoundary.visible = false
        _map.center = savedCenter
        _map.zoomLevel = savedZoom
        mapType = savedMapType
    }

    function resetMapToDefaults() {
        _map.center = QGroundControl.flightMapPosition
        _map.zoomLevel = QGroundControl.flightMapZoom
    }

    ExclusiveGroup {
        id: _dropButtonsExclusiveGroup
    }

    onMapTypeChanged: {
        updateMap()
        if(isMapInteractive) {
            QGroundControl.mapEngineManager.saveSetting(mapKey, mapType)
        }
    }

    MessageDialog {
        id:         errorDialog
        visible:    false
        text:       QGroundControl.mapEngineManager.errorMessage
        icon:       StandardIcon.Critical
        standardButtons: StandardButton.Ok
        title:      qsTr("Error Message")
        onYes: {
            errorDialog.visible = false
        }
    }

    Component {
        id: optionsDialogComponent

        QGCViewDialog {
            id: optionDialog

            function accept() {
                QGroundControl.mapEngineManager.mapboxToken  = mapBoxToken.text
                QGroundControl.mapEngineManager.maxDiskCache = parseInt(maxCacheSize.text)
                QGroundControl.mapEngineManager.maxMemCache  = parseInt(maxCacheMemSize.text)
                optionDialog.hideDialog()
            }

            QGCFlickable {
                anchors.fill:   parent
                contentHeight:  optionsColumn.height

                Column {
                    id:                 optionsColumn
                    anchors.margins:    ScreenTools.defaultFontPixelWidth
                    anchors.left:       parent.left
                    anchors.right:      parent.right
                    anchors.top:        parent.top
                    spacing:            ScreenTools.defaultFontPixelHeight / 2

                    QGCLabel { text:       qsTr("Max Cache Disk Size (MB):") }

                    QGCTextField {
                        id:                 maxCacheSize
                        maximumLength:      6
                        inputMethodHints:   Qt.ImhDigitsOnly
                        validator:          IntValidator {bottom: 1; top: 262144;}
                        text:               QGroundControl.mapEngineManager.maxDiskCache
                    }

                    Item { width: 1; height: 1 }

                    QGCLabel { text:       qsTr("Max Cache Memory Size (MB):") }

                    QGCTextField {
                        id:                 maxCacheMemSize
                        maximumLength:      4
                        inputMethodHints:   Qt.ImhDigitsOnly
                        validator:          IntValidator {bottom: 1; top: 1024;}
                        text:               QGroundControl.mapEngineManager.maxMemCache
                    }

                    QGCLabel {
                        font.pointSize: _adjustableFontPointSize
                        text:           qsTr("Memory cache changes require a restart to take effect.")
                    }

                    Item { width: 1; height: 1 }

                    QGCLabel { text: qsTr("MapBox Access Token") }

                    QGCTextField {
                        id:             mapBoxToken
                        maximumLength:  256
                        width:          ScreenTools.defaultFontPixelWidth * 30
                        text:           QGroundControl.mapEngineManager.mapboxToken
                    }

                    QGCLabel {
                        text:           qsTr("With an access token, you can use MapBox Maps.")
                        font.pointSize: _adjustableFontPointSize
                    }
                } // GridLayout
            } // QGCFlickable
        } // QGCViewDialog - optionsDialog
    } // Component - optionsDialogComponent

    Component {
        id: deleteConfirmationDialogComponent
        QGCViewMessage {
            id:  deleteConfirmationDialog
            message: {
                if(offlineMapView._currentSelection.defaultSet)
                    return qsTr("This will delete all tiles INCLUDING the tile sets you have created yourself.\n\nIs this really what you want?");
                else
                    return qsTr("Delete %1 and all its tiles.\n\nIs this really what you want?").arg(offlineMapView._currentSelection.name);
            }
            function accept() {
                QGroundControl.mapEngineManager.deleteTileSet(offlineMapView._currentSelection)
                deleteConfirmationDialog.hideDialog()
                leaveInfoView()
                showList()
            }
        }
    }

    QGCViewPanel {
        id:                 panel
        anchors.fill:       parent

        Map {
            id:                 _map
            anchors.fill:       parent
            center:             QGroundControl.flightMapPosition
            visible:            false
            gesture.flickDeceleration:  3000

            property bool isSatelliteMap: activeMapType.name.indexOf("Satellite") > -1 || activeMapType.name.indexOf("Hybrid") > -1

            plugin: Plugin { name: "QGroundControl" }

            MapRectangle {
                id:             mapBoundary
                border.width:   2
                border.color:   "red"
                color:          Qt.rgba(1,0,0,0.05)
                smooth:         true
                antialiasing:   true
            }

            Component.onCompleted: resetMapToDefaults()

            onCenterChanged:    handleChanges()
            onZoomLevelChanged: handleChanges()
            onWidthChanged:     handleChanges()
            onHeightChanged:    handleChanges()

            // Used to make pinch zoom work
            MouseArea {
                anchors.fill: parent
            }

            MapScale {
                anchors.leftMargin:     ScreenTools.defaultFontPixelWidth / 2
                anchors.bottomMargin:   anchors.leftMargin
                anchors.left:           parent.left
                anchors.bottom:         parent.bottom
                mapControl:             _map
            }

            //-----------------------------------------------------------------
            //-- Show Set Info
            Rectangle {
                id:                 infoView
                anchors.margins:    ScreenTools.defaultFontPixelHeight
                anchors.right:      parent.right
                anchors.verticalCenter: parent.verticalCenter
                width:              tileInfoColumn.width  + (ScreenTools.defaultFontPixelWidth  * 2)
                height:             tileInfoColumn.height + (ScreenTools.defaultFontPixelHeight * 2)
                color:              Qt.rgba(qgcPal.window.r, qgcPal.window.g, qgcPal.window.b, 0.85)
                radius:             ScreenTools.defaultFontPixelWidth * 0.5
                visible:            false

                property bool       _extraButton: {
                    if(!offlineMapView._currentSelection)
                        return false;
                    var curSel = offlineMapView._currentSelection;
                    return !_defaultSet && ((!curSel.complete && !curSel.downloading) || (!curSel.complete && curSel.downloading));
                }

                property real       _labelWidth:    ScreenTools.defaultFontPixelWidth * 10
                property real       _valueWidth:    ScreenTools.defaultFontPixelWidth * 14
                Column {
                    id:                 tileInfoColumn
                    anchors.margins:    ScreenTools.defaultFontPixelHeight * 0.5
                    spacing:            ScreenTools.defaultFontPixelHeight * 0.5
                    anchors.centerIn:   parent
                    QGCLabel {
                        anchors.left:   parent.left
                        anchors.right:  parent.right
                        wrapMode:       Text.WordWrap
                        text:           offlineMapView._currentSelection ? offlineMapView._currentSelection.name : ""
                        font.pointSize: _saveRealEstate ? ScreenTools.defaultFontPointSize : ScreenTools.mediumFontPointSize
                        horizontalAlignment: Text.AlignHCenter
                    }
                    QGCLabel {
                        anchors.left:   parent.left
                        anchors.right:  parent.right
                        wrapMode:       Text.WordWrap
                        text: {
                            if(offlineMapView._currentSelection) {
                                if(offlineMapView._currentSelection.defaultSet)
                                    return qsTr("System Wide Tile Cache");
                                else
                                    return "(" + offlineMapView._currentSelection.mapTypeStr + ")"
                            } else
                                return "";
                        }
                        horizontalAlignment: Text.AlignHCenter
                    }
                    //-- Tile Sets
                    Row {
                        spacing:    ScreenTools.defaultFontPixelWidth
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible:    !_defaultSet
                        QGCLabel {  text: qsTr("Zoom Levels:"); width: infoView._labelWidth; }
                        QGCLabel {  text: offlineMapView._currentSelection ? (offlineMapView._currentSelection.minZoom + " - " + offlineMapView._currentSelection.maxZoom) : ""; horizontalAlignment: Text.AlignRight; width: infoView._valueWidth; }
                    }
                    Row {
                        spacing:    ScreenTools.defaultFontPixelWidth
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible:    !_defaultSet
                        QGCLabel {  text: qsTr("Total:"); width: infoView._labelWidth; }
                        QGCLabel {  text: (offlineMapView._currentSelection ? offlineMapView._currentSelection.totalTileCountStr : "") + " (" + (offlineMapView._currentSelection ? offlineMapView._currentSelection.totalTilesSizeStr : "") + ")"; horizontalAlignment: Text.AlignRight; width: infoView._valueWidth; }
                    }
                    Row {
                        spacing:    ScreenTools.defaultFontPixelWidth
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible:    offlineMapView && offlineMapView._currentSelection && !_defaultSet && offlineMapView._currentSelection.uniqueTileCount > 0
                        QGCLabel {  text: qsTr("Unique:"); width: infoView._labelWidth; }
                        QGCLabel {  text: (offlineMapView._currentSelection ? offlineMapView._currentSelection.uniqueTileCountStr : "") + " (" + (offlineMapView._currentSelection ? offlineMapView._currentSelection.uniqueTileSizeStr : "") + ")"; horizontalAlignment: Text.AlignRight; width: infoView._valueWidth; }
                    }

                    Row {
                        spacing:    ScreenTools.defaultFontPixelWidth
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible:    offlineMapView && offlineMapView._currentSelection && !_defaultSet && !offlineMapView._currentSelection.complete
                        QGCLabel {  text: qsTr("Downloaded:"); width: infoView._labelWidth; }
                        QGCLabel {  text: (offlineMapView._currentSelection ? offlineMapView._currentSelection.savedTileCountStr : "") + " (" + (offlineMapView._currentSelection ? offlineMapView._currentSelection.savedTileSizeStr : "") + ")"; horizontalAlignment: Text.AlignRight; width: infoView._valueWidth; }
                    }
                    Row {
                        spacing:    ScreenTools.defaultFontPixelWidth
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible:    offlineMapView && offlineMapView._currentSelection && !_defaultSet && !offlineMapView._currentSelection.complete && offlineMapView._currentSelection.errorCount > 0
                        QGCLabel {  text: qsTr("Error Count:"); width: infoView._labelWidth; }
                        QGCLabel {  text: offlineMapView._currentSelection ? offlineMapView._currentSelection.errorCountStr : ""; horizontalAlignment: Text.AlignRight; width: infoView._valueWidth; }
                    }
                    //-- Default Tile Set
                    Row {
                        spacing:    ScreenTools.defaultFontPixelWidth
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible:    _defaultSet
                        QGCLabel { text: qsTr("Size:"); width: infoView._labelWidth; }
                        QGCLabel { text: offlineMapView._currentSelection ? offlineMapView._currentSelection.savedTileSizeStr  : ""; horizontalAlignment: Text.AlignRight; width: infoView._valueWidth; }
                    }
                    Row {
                        spacing:    ScreenTools.defaultFontPixelWidth
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible:    _defaultSet
                        QGCLabel { text: qsTr("Tile Count:"); width: infoView._labelWidth; }
                        QGCLabel { text: offlineMapView._currentSelection ? offlineMapView._currentSelection.savedTileCountStr : ""; horizontalAlignment: Text.AlignRight; width: infoView._valueWidth; }
                    }
                    Row {
                        spacing:    ScreenTools.defaultFontPixelWidth
                        anchors.horizontalCenter: parent.horizontalCenter
                        QGCButton {
                            text:       qsTr("Resume Download")
                            visible:    offlineMapView._currentSelection && offlineMapView._currentSelection && !_defaultSet && (!offlineMapView._currentSelection.complete && !offlineMapView._currentSelection.downloading)
                            width:      ScreenTools.defaultFontPixelWidth * 16
                            onClicked: {
                                if(offlineMapView._currentSelection)
                                    offlineMapView._currentSelection.resumeDownloadTask()
                            }
                        }
                        QGCButton {
                            text:       qsTr("Cancel Download")
                            visible:    offlineMapView._currentSelection && offlineMapView._currentSelection && !_defaultSet && (!offlineMapView._currentSelection.complete && offlineMapView._currentSelection.downloading)
                            width:      ScreenTools.defaultFontPixelWidth * 16
                            onClicked: {
                                if(offlineMapView._currentSelection)
                                    offlineMapView._currentSelection.cancelDownloadTask()
                            }
                        }
                        QGCButton {
                            text:       qsTr("Delete")
                            width:      ScreenTools.defaultFontPixelWidth * (infoView._extraButton ? 6 : 10)
                            onClicked:  showDialog(deleteConfirmationDialogComponent, qsTr("Confirm Delete"), qgcView.showDialogDefaultWidth, StandardButton.Yes | StandardButton.No)
                        }
                        QGCButton {
                            text:       qsTr("Close")
                            width:      ScreenTools.defaultFontPixelWidth * (infoView._extraButton ? 6 : 10)
                            onClicked: {
                                leaveInfoView()
                                showList()
                            }
                        }
                    }
                }
            } // Rectangle - infoView

            //-----------------------------------------------------------------
            //-- Add new set
            Item {
                id:             addNewSetView
                anchors.fill:   parent
                visible:        false

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin:     _margins
                    anchors.left:           parent.left
                    spacing:                _margins

                    QGCButton {
                        text:       "Show zoom previews"
                        visible:    !_showPreview
                        onClicked:  _showPreview = !_showPreview
                    }

                    Map {
                        id:                 minZoomPreview
                        width:              addNewSetView.width / 4
                        height:             addNewSetView.height / 4
                        center:             _map.center
                        activeMapType:      _map.activeMapType
                        zoomLevel:          sliderMinZoom.value
                        gesture.enabled:    false
                        visible:            _showPreview

                        property bool isSatelliteMap: activeMapType.name.indexOf("Satellite") > -1 || activeMapType.name.indexOf("Hybrid") > -1

                        plugin: Plugin { name: "QGroundControl" }

                        MapScale {
                            anchors.leftMargin:     ScreenTools.defaultFontPixelWidth / 2
                            anchors.bottomMargin:   anchors.leftMargin
                            anchors.left:           parent.left
                            anchors.bottom:         parent.bottom
                            mapControl:             parent
                        }

                        Rectangle {
                            anchors.fill:   parent
                            border.color:   _mapAdjustedColor
                            color:          "transparent"

                            QGCMapLabel {
                                anchors.centerIn:   parent
                                map:                minZoomPreview
                                text:               qsTr("Min Zoom: %1").arg(sliderMinZoom.value)
                            }
                            MouseArea {
                                anchors.fill:   parent
                                onClicked:      _showPreview = false
                            }
                        }
                    } // Map

                    Map {
                        id:                 maxZoomPreview
                        width:              minZoomPreview.width
                        height:             minZoomPreview.height
                        center:             _map.center
                        activeMapType:      _map.activeMapType
                        zoomLevel:          sliderMaxZoom.value
                        gesture.enabled:    false
                        visible:            _showPreview

                        property bool isSatelliteMap: activeMapType.name.indexOf("Satellite") > -1 || activeMapType.name.indexOf("Hybrid") > -1

                        plugin: Plugin { name: "QGroundControl" }

                        MapScale {
                            anchors.leftMargin:     ScreenTools.defaultFontPixelWidth / 2
                            anchors.bottomMargin:   anchors.leftMargin
                            anchors.left:           parent.left
                            anchors.bottom:         parent.bottom
                            mapControl:             parent
                        }

                        Rectangle {
                            anchors.fill:   parent
                            border.color:   _mapAdjustedColor
                            color:          "transparent"

                            QGCMapLabel {
                                anchors.centerIn:   parent
                                map:                maxZoomPreview
                                text:               qsTr("Max Zoom: %1").arg(sliderMaxZoom.value)
                            }
                            MouseArea {
                                anchors.fill:   parent
                                onClicked:      _showPreview = false
                            }
                        }
                    } // Map
                }
            } // Item - Add new set view

            CenterMapDropButton {
                topMargin:          0
                anchors.margins:    _margins
                anchors.left:       map.left
                anchors.top:        map.top
                map:                _map
                showMission:        false
                showAllItems:       false
                visible:            addNewSetView.visible
            }
        } // Map

        //-- Add new set dialog
        Rectangle {
            anchors.margins:    ScreenTools.defaultFontPixelWidth
            anchors.verticalCenter: parent.verticalCenter
            anchors.right:      parent.right
            visible:            addNewSetView.visible
            width:              ScreenTools.defaultFontPixelWidth * (ScreenTools.isTinyScreen ? 24 : 28)
            height:             Math.min(parent.height - (anchors.margins * 2), addNewSetFlickable.y + addNewSetColumn.height + addNewSetLabel.anchors.margins)
            color:              Qt.rgba(qgcPal.window.r, qgcPal.window.g, qgcPal.window.b, 0.85)
            radius:             ScreenTools.defaultFontPixelWidth * 0.5

            MouseArea {
                anchors.fill:   parent
                onWheel:        { wheel.accepted = true; }
                onPressed:      { mouse.accepted = true; }
                onReleased:     { mouse.accepted = true; }
            }

            QGCLabel {
                id:                 addNewSetLabel
                anchors.margins:    ScreenTools.defaultFontPixelHeight / 2
                anchors.top:        parent.top
                anchors.left:       parent.left
                anchors.right:      parent.right
                wrapMode:           Text.WordWrap
                text:               qsTr("Add New Set")
                font.pointSize:     _saveRealEstate ? ScreenTools.defaultFontPointSize : ScreenTools.mediumFontPointSize
                horizontalAlignment: Text.AlignHCenter
            }

            QGCFlickable {
                id:                     addNewSetFlickable
                anchors.leftMargin:     ScreenTools.defaultFontPixelWidth
                anchors.rightMargin:    anchors.leftMargin
                anchors.topMargin:      ScreenTools.defaultFontPixelWidth / 3
                anchors.bottomMargin:   anchors.topMargin
                anchors.top:            addNewSetLabel.bottom
                anchors.left:           parent.left
                anchors.right:          parent.right
                anchors.bottom:         parent.bottom
                clip:                   true
                contentHeight:          addNewSetColumn.height

                Column {
                    id:                 addNewSetColumn
                    anchors.left:       parent.left
                    anchors.right:      parent.right
                    spacing:            ScreenTools.defaultFontPixelHeight * (ScreenTools.isTinyScreen ? 0.25 : 0.5)

                    Column {
                        spacing:            ScreenTools.isTinyScreen ? 0 : ScreenTools.defaultFontPixelHeight * 0.25
                        anchors.left:       parent.left
                        anchors.right:      parent.right
                        QGCLabel { text: qsTr("Name:") }
                        QGCTextField {
                            id:             setName
                            anchors.left:   parent.left
                            anchors.right:  parent.right
                        }
                    }

                    Column {
                        spacing:            ScreenTools.isTinyScreen ? 0 : ScreenTools.defaultFontPixelHeight * 0.25
                        anchors.left:       parent.left
                        anchors.right:      parent.right
                        QGCLabel {
                            text:       qsTr("Map type:")
                            visible:    !_saveRealEstate
                        }
                        QGCComboBox {
                            id:             mapCombo
                            anchors.left:   parent.left
                            anchors.right:  parent.right
                            model:          QGroundControl.mapEngineManager.mapList
                            onActivated: {
                                mapType = textAt(index)
                                if(_dropButtonsExclusiveGroup.current)
                                    _dropButtonsExclusiveGroup.current.checked = false
                                _dropButtonsExclusiveGroup.current = null
                            }
                            Component.onCompleted: {
                                var index = mapCombo.find(mapType)
                                if (index === -1) {
                                    console.warn("Active map name not in combo", mapType)
                                } else {
                                    mapCombo.currentIndex = index
                                }
                            }
                        }
                    }

                    Rectangle {
                        anchors.left:   parent.left
                        anchors.right:  parent.right
                        height:         zoomColumn.height + ScreenTools.defaultFontPixelHeight * 0.5
                        color:          qgcPal.window
                        border.color:   qgcPal.text
                        radius:         ScreenTools.defaultFontPixelWidth * 0.5

                        Column {
                            id:                 zoomColumn
                            spacing:            ScreenTools.isTinyScreen ? 0 : ScreenTools.defaultFontPixelHeight * 0.5
                            anchors.margins:    ScreenTools.defaultFontPixelHeight * 0.25
                            anchors.top:        parent.top
                            anchors.left:       parent.left
                            anchors.right:      parent.right

                            QGCLabel {
                                text:           qsTr("Min/Max Zoom Levels")
                                font.pointSize: _adjustableFontPointSize
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            Slider {
                                id:                         sliderMinZoom
                                anchors.left:               parent.left
                                anchors.right:              parent.right
                                height:                     sliderTouchArea * 1.25
                                minimumValue:               minZoomLevel
                                maximumValue:               maxZoomLevel
                                stepSize:                   1
                                updateValueWhileDragging:   true
                                property real _savedZoom
                                Component.onCompleted:      Math.max(sliderMinZoom.value = _map.zoomLevel - 4, 2)
                                onValueChanged: {
                                    if(sliderMinZoom.value > sliderMaxZoom.value) {
                                        sliderMaxZoom.value = sliderMinZoom.value
                                    }
                                    handleChanges()
                                }
                                style: SliderStyle {
                                    groove: Rectangle {
                                        implicitWidth:  sliderMinZoom.width
                                        implicitHeight: 4
                                        color:          qgcPal.colorBlue
                                        radius:         4
                                    }
                                    handle: Rectangle {
                                        anchors.centerIn: parent
                                        color:          qgcPal.button
                                        border.color:   qgcPal.buttonText
                                        border.width:   1
                                        implicitWidth:  sliderTouchArea
                                        implicitHeight: sliderTouchArea
                                        radius:         sliderTouchArea * 0.5
                                        Label {
                                            text:               sliderMinZoom.value
                                            anchors.centerIn:   parent
                                            font.family:        ScreenTools.normalFontFamily
                                            font.pointSize:     ScreenTools.smallFontPointSize
                                            color:              qgcPal.buttonText
                                        }
                                    }
                                }
                            } // Slider - min zoom

                            Slider {
                                id:                         sliderMaxZoom
                                anchors.left:               parent.left
                                anchors.right:              parent.right
                                height:                     sliderTouchArea * 1.25
                                minimumValue:               minZoomLevel
                                maximumValue:               maxZoomLevel
                                stepSize:                   1
                                updateValueWhileDragging:   true
                                property real _savedZoom
                                Component.onCompleted:      Math.min(sliderMaxZoom.value = _map.zoomLevel + 2, 20)
                                onValueChanged: {
                                    if(sliderMaxZoom.value < sliderMinZoom.value) {
                                        sliderMinZoom.value = sliderMaxZoom.value
                                    }
                                    handleChanges()
                                }
                                style: SliderStyle {
                                    groove: Rectangle {
                                        implicitWidth:  sliderMaxZoom.width
                                        implicitHeight: 4
                                        color:          qgcPal.colorBlue
                                        radius:         4
                                    }
                                    handle: Rectangle {
                                        anchors.centerIn: parent
                                        color:          qgcPal.button
                                        border.color:   qgcPal.buttonText
                                        border.width:   1
                                        implicitWidth:  sliderTouchArea
                                        implicitHeight: sliderTouchArea
                                        radius:         sliderTouchArea * 0.5
                                        Label {
                                            text:               sliderMaxZoom.value
                                            anchors.centerIn:   parent
                                            font.family:        ScreenTools.normalFontFamily
                                            font.pointSize:     ScreenTools.smallFontPointSize
                                            color:              qgcPal.buttonText
                                        }
                                    }
                                }
                            } // Slider - max zoom

                            GridLayout {
                                columns:    2
                                rowSpacing: ScreenTools.isTinyScreen ? 0 : ScreenTools.defaultFontPixelHeight * 0.5
                                QGCLabel {
                                    text:           qsTr("Tile Count:")
                                    font.pointSize: _adjustableFontPointSize
                                }
                                QGCLabel {
                                    text:            QGroundControl.mapEngineManager.tileCountStr
                                    font.pointSize: _adjustableFontPointSize
                                }

                                QGCLabel {
                                    text:           qsTr("Est Size:")
                                    font.pointSize: _adjustableFontPointSize
                                }
                                QGCLabel {
                                    text:           QGroundControl.mapEngineManager.tileSizeStr
                                    font.pointSize: _adjustableFontPointSize
                                }
                            }
                        } // Column - Zoom info
                    } // Rectangle - Zoom info

                    QGCLabel {
                        text:       qsTr("Too many tiles")
                        visible:    _tooManyTiles
                        color:      qgcPal.warningText
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Row {
                        id: addButtonRow
                        spacing: ScreenTools.defaultFontPixelWidth
                        anchors.horizontalCenter: parent.horizontalCenter
                        QGCButton {
                            text:       qsTr("Download")
                            width:      (addNewSetColumn.width * 0.5) - (addButtonRow.spacing * 0.5)
                            enabled:    !_tooManyTiles && setName.text.length > 0
                            onClicked: {
                                if(QGroundControl.mapEngineManager.findName(setName.text)) {
                                    duplicateName.visible = true
                                } else {
                                    QGroundControl.mapEngineManager.startDownload(setName.text, mapType);
                                    showList()
                                }
                            }
                        }
                        QGCButton {
                            text:       qsTr("Cancel")
                            width:      (addNewSetColumn.width * 0.5) - (addButtonRow.spacing * 0.5)
                            onClicked: {
                                showList()
                            }
                        }
                    }

                } // Column
            } // QGCFlickable
        } // Rectangle - Add new set dialog

        QGCFlickable {
            id:                 _tileSetList
            clip:               true
            anchors.margins:    ScreenTools.defaultFontPixelWidth
            anchors.top:        parent.top
            anchors.bottom:     _listButtonRow.top
            anchors.left:       parent.left
            anchors.right:      parent.right
            contentHeight:      _cacheList.height

            Column {
                id:         _cacheList
                width:      Math.min(_tileSetList.width, (ScreenTools.defaultFontPixelWidth  * 50).toFixed(0))
                spacing:    ScreenTools.defaultFontPixelHeight * 0.5
                anchors.horizontalCenter: parent.horizontalCenter
                OfflineMapButton {
                    id:             firstButton
                    text:           qsTr("Add new set")
                    width:          _cacheList.width
                    height:         ScreenTools.defaultFontPixelHeight * 2
                    onClicked: {
                        offlineMapView._currentSelection = null
                        addNewSet()
                    }
                }
                Repeater {
                    model: QGroundControl.mapEngineManager.tileSets
                    delegate: OfflineMapButton {
                        text:           object.name
                        size:           object.downloadStatus
                        tiles:          object.totalTileCount
                        complete:       object.complete
                        width:          firstButton.width
                        height:         ScreenTools.defaultFontPixelHeight * 2
                        onClicked: {
                            offlineMapView._currentSelection = object
                            showInfo()
                        }
                    }
                }
            }
        }
        Row {
            id:                 _listButtonRow
            visible:            _tileSetList.visible
            spacing:            _margins
            anchors.bottom:     parent.bottom
            anchors.margins:    ScreenTools.defaultFontPixelWidth
            anchors.horizontalCenter: parent.horizontalCenter
            QGCButton {
                text:           qsTr("Import")
                width:          _buttonSize
                visible:        !ScreenTools.isMobile
                onClicked:      rootLoader.sourceComponent = importDialog
            }
            QGCButton {
                text:           qsTr("Export")
                width:          _buttonSize
                visible:        !ScreenTools.isMobile
                enabled:        QGroundControl.mapEngineManager.tileSets.count > 1
                onClicked:      showExport()
            }
            QGCButton {
                text:           qsTr("Options")
                width:          _buttonSize
                onClicked:      showDialog(optionsDialogComponent, qsTr("Offline Maps Options"), qgcView.showDialogDefaultWidth, StandardButton.Save | StandardButton.Cancel)
            }
        }

        //-- Export Tile Sets
        QGCFlickable {
            id:                 _exporTiles
            clip:               true
            visible:            false
            anchors.margins:    ScreenTools.defaultFontPixelWidth
            anchors.top:        parent.top
            anchors.bottom:     _exportButtonRow.top
            anchors.left:       parent.left
            anchors.right:      parent.right
            contentHeight:      _exportList.height
            Column {
                id:         _exportList
                width:      Math.min(_exporTiles.width, (ScreenTools.defaultFontPixelWidth  * 50).toFixed(0))
                spacing:    ScreenTools.defaultFontPixelHeight * 0.5
                anchors.horizontalCenter: parent.horizontalCenter
                QGCLabel {
                    text:           qsTr("Select Tile Sets to Export")
                    font.pointSize: ScreenTools.mediumFontPointSize
                }
                Item { width: 1; height: ScreenTools.defaultFontPixelHeight; }
                Repeater {
                    model: QGroundControl.mapEngineManager.tileSets
                    delegate: QGCCheckBox {
                        text:           object.name
                        checked:        object.selected
                        onClicked: {
                            object.selected = checked
                        }
                    }
                }
            }
        }
        Row {
            id:                 _exportButtonRow
            visible:            _exporTiles.visible
            spacing:            _margins
            anchors.bottom:     parent.bottom
            anchors.margins:    ScreenTools.defaultFontPixelWidth
            anchors.horizontalCenter: parent.horizontalCenter
            QGCButton {
                text:           qsTr("Select All")
                width:          _bigButtonSize
                onClicked:      QGroundControl.mapEngineManager.selectAll()
            }
            QGCButton {
                text:           qsTr("Select None")
                width:          _bigButtonSize
                onClicked:      QGroundControl.mapEngineManager.selectNone()
            }
            QGCButton {
                text:           qsTr("Export to Disk")
                width:          _bigButtonSize
                enabled:        QGroundControl.mapEngineManager.selectedCount > 0
                onClicked: {
                    showList();
                    if(QGroundControl.mapEngineManager.exportSets()) {
                        rootLoader.sourceComponent = exportToDiskProgress
                    }
                }
            }
            QGCButton {
                text:           qsTr("Export to Device")
                width:          _bigButtonSize
                enabled:        QGroundControl.mapEngineManager.selectedCount > 0
                onClicked: {
                    rootLoader.sourceComponent = exportToDevice
                }
            }
            QGCButton {
                text:           qsTr("Cancel")
                width:          _bigButtonSize
                onClicked:       showList()
            }
        }
    } // QGCViewPanel

    Component {
        id: exportToDiskProgress
        Rectangle {
            width:      mainWindow.width
            height:     mainWindow.height
            color:      "black"
            anchors.centerIn: parent
            Rectangle {
                width:  parent.width  * 0.5
                height: exportCol.height * 1.25
                radius: ScreenTools.defaultFontPixelWidth
                color:  qgcPal.windowShadeDark
                border.color: qgcPal.text
                anchors.centerIn: parent
                Column {
                    id:                 exportCol
                    spacing:            ScreenTools.defaultFontPixelHeight
                    width:              parent.width
                    anchors.centerIn:   parent
                    QGCLabel {
                        text:               QGroundControl.mapEngineManager.importAction === QGCMapEngineManager.ActionExporting ? qsTr("Tile Set Export Progress") : qsTr("Tile Set Export Completed")
                        font.family:        ScreenTools.demiboldFontFamily
                        font.pointSize:     ScreenTools.mediumFontPointSize
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    ProgressBar {
                        id:             progressBar
                        width:          parent.width * 0.45
                        maximumValue:   100
                        value:          QGroundControl.mapEngineManager.actionProgress
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    BusyIndicator {
                        visible:        QGroundControl.mapEngineManager ? QGroundControl.mapEngineManager.exporting : false
                        running:        QGroundControl.mapEngineManager ? QGroundControl.mapEngineManager.exporting : false
                        width:          exportCloseButton.height
                        height:         exportCloseButton.height
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    QGCButton {
                        id:             exportCloseButton
                        text:           qsTr("Close")
                        width:          _buttonSize
                        visible:        !QGroundControl.mapEngineManager.exporting
                        anchors.horizontalCenter: parent.horizontalCenter
                        onClicked: {
                            rootLoader.sourceComponent = null
                        }
                    }
                }
            }
        }
    }

    Component {
        id: importDialog
        Rectangle {
            width:      mainWindow.width
            height:     mainWindow.height
            color:      "black"
            anchors.centerIn: parent
            Rectangle {
                width:  parent.width  * 0.5
                height: importCol.height * 1.5
                radius: ScreenTools.defaultFontPixelWidth
                color:  qgcPal.windowShadeDark
                border.color: qgcPal.text
                anchors.centerIn: parent
                Column {
                    id:                 importCol
                    spacing:            ScreenTools.defaultFontPixelHeight
                    width:              parent.width
                    anchors.centerIn:   parent
                    QGCLabel {
                        text: {
                            if(QGroundControl.mapEngineManager.importAction === QGCMapEngineManager.ActionNone) {
                                return qsTr("Map Tile Set Import");
                            } else if(QGroundControl.mapEngineManager.importAction === QGCMapEngineManager.ActionImporting) {
                                return qsTr("Map Tile Set Import Progress");
                            } else {
                                return qsTr("Map Tile Set Import Completed");
                            }
                        }
                        font.family:        ScreenTools.demiboldFontFamily
                        font.pointSize:     ScreenTools.mediumFontPointSize
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    ProgressBar {
                        id:             progressBar
                        width:          parent.width * 0.45
                        maximumValue:   100
                        visible:        QGroundControl.mapEngineManager.importAction === QGCMapEngineManager.ActionImporting
                        value:          QGroundControl.mapEngineManager.actionProgress
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    BusyIndicator {
                        visible:        QGroundControl.mapEngineManager.importAction === QGCMapEngineManager.ActionImporting
                        running:        QGroundControl.mapEngineManager.importAction === QGCMapEngineManager.ActionImporting
                        width:          ScreenTools.defaultFontPixelWidth * 2
                        height:         width
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    ExclusiveGroup { id: radioGroup }
                    Column {
                        spacing:            ScreenTools.defaultFontPixelHeight
                        width:              ScreenTools.defaultFontPixelWidth * 24
                        anchors.horizontalCenter: parent.horizontalCenter
                        QGCRadioButton {
                            exclusiveGroup: radioGroup
                            text:           qsTr("Append to existing set")
                            checked:        !QGroundControl.mapEngineManager.importReplace
                            onClicked:      QGroundControl.mapEngineManager.importReplace = !checked
                            visible:        QGroundControl.mapEngineManager.importAction === QGCMapEngineManager.ActionNone
                        }
                        QGCRadioButton {
                            exclusiveGroup: radioGroup
                            text:           qsTr("Replace existing set")
                            checked:        QGroundControl.mapEngineManager.importReplace
                            onClicked:      QGroundControl.mapEngineManager.importReplace = checked
                            visible:        QGroundControl.mapEngineManager.importAction === QGCMapEngineManager.ActionNone
                        }
                    }
                    QGCButton {
                        text:           qsTr("Close")
                        width:          _bigButtonSize * 1.25
                        visible:        QGroundControl.mapEngineManager.importAction === QGCMapEngineManager.ActionDone
                        anchors.horizontalCenter: parent.horizontalCenter
                        onClicked: {
                            showList();
                            rootLoader.sourceComponent = null
                        }
                    }
                    Row {
                        spacing:            _margins
                        visible:            QGroundControl.mapEngineManager.importAction === QGCMapEngineManager.ActionNone
                        anchors.horizontalCenter: parent.horizontalCenter
                        QGCButton {
                            text:           qsTr("Import From Disk")
                            width:          _bigButtonSize * 1.25
                            onClicked: {
                                if(!QGroundControl.mapEngineManager.importSets()) {
                                    showList();
                                    rootLoader.sourceComponent = null
                                }
                            }
                        }
                        QGCButton {
                            text:           qsTr("Import From Device")
                            width:          _bigButtonSize * 1.25
                            onClicked: {
                                rootLoader.sourceComponent = importFromDevice
                            }
                        }
                        QGCButton {
                            text:           qsTr("Cancel")
                            width:          _bigButtonSize * 1.25
                            onClicked: {
                                showList();
                                rootLoader.sourceComponent = null
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: importFromDevice
        Rectangle {
            width:      mainWindow.width
            height:     mainWindow.height
            color:      "black"
            anchors.centerIn: parent
            Rectangle {
                width:  parent.width  * 0.45
                height: importCol.height * 1.5
                radius: ScreenTools.defaultFontPixelWidth
                color:  qgcPal.windowShadeDark
                border.color: qgcPal.text
                anchors.centerIn: parent
                Column {
                    id:                 importCol
                    spacing:            ScreenTools.defaultFontPixelHeight
                    width:              parent.width
                    anchors.centerIn:   parent
                    QGCLabel {
                        text:           qsTr("Map Tile Set Import From Device");
                        font.family:        ScreenTools.demiboldFontFamily
                        font.pointSize:     ScreenTools.mediumFontPointSize
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    QGCLabel {
                        text:           qsTr("NOT YET IMPLEMENTED");
                        font.family:        ScreenTools.demiboldFontFamily
                        font.pointSize:     ScreenTools.mediumFontPointSize
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    QGCButton {
                        text:           qsTr("Close")
                        width:          _bigButtonSize * 1.25
                        anchors.horizontalCenter: parent.horizontalCenter
                        onClicked: {
                            showList();
                            rootLoader.sourceComponent = null
                        }
                    }
                }
            }
        }
    }

    Component {
        id: exportToDevice
        Rectangle {
            width:      mainWindow.width
            height:     mainWindow.height
            color:      "black"
            anchors.centerIn: parent
            Rectangle {
                width:  parent.width  * 0.45
                height: importCol.height * 1.5
                radius: ScreenTools.defaultFontPixelWidth
                color:  qgcPal.windowShadeDark
                border.color: qgcPal.text
                anchors.centerIn: parent
                Column {
                    id:                 importCol
                    spacing:            ScreenTools.defaultFontPixelHeight
                    width:              parent.width
                    anchors.centerIn:   parent
                    QGCLabel {
                        text:           qsTr("Map Tile Set Export To Device");
                        font.family:        ScreenTools.demiboldFontFamily
                        font.pointSize:     ScreenTools.mediumFontPointSize
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    QGCLabel {
                        text:           qsTr("NOT YET IMPLEMENTED");
                        font.family:        ScreenTools.demiboldFontFamily
                        font.pointSize:     ScreenTools.mediumFontPointSize
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    QGCButton {
                        text:           qsTr("Close")
                        width:          _bigButtonSize * 1.25
                        anchors.horizontalCenter: parent.horizontalCenter
                        onClicked: {
                            showList();
                            rootLoader.sourceComponent = null
                        }
                    }
                }
            }
        }
    }

} // QGCView
