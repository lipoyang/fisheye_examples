cmake_minimum_required(VERSION 3.5)

project(fisheye_qt VERSION 0.1 LANGUAGES CXX)

set(CMAKE_AUTOUIC ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(QT NAMES Qt6 Qt5 REQUIRED COMPONENTS Widgets)
find_package(Qt${QT_VERSION_MAJOR} REQUIRED COMPONENTS Widgets)

set(PROJECT_SOURCES
        main.cpp
        mainwindow.cpp
        mainwindow.h
        mainwindow.ui
)

# add bitmap image file to target directory
set(RES_PATH ${CMAKE_CURRENT_SOURCE_DIR}/resource)
set(TGT_PSTH ${CMAKE_BINARY_DIR})
if(WIN32)
    string(REPLACE "/" "\\" RES_PATH ${RES_PATH})
    string(REPLACE "/" "\\" TGT_PSTH ${TGT_PSTH}/resource)
    set(COPY_CMD xcopy /I /S /Y)
else()
    set(COPY_CMD cp -rf)
endif()

if(${QT_VERSION_MAJOR} GREATER_EQUAL 6)
    qt_add_executable(fisheye_qt
        MANUAL_FINALIZATION
        ${PROJECT_SOURCES}
        resource/lena_std.bmp
    )
    # add bitmap image file to target directory
    add_custom_command(
        TARGET fisheye_qt POST_BUILD
        COMMAND ${COPY_CMD} ${RES_PATH} ${TGT_PSTH}
    )
# Define target properties for Android with Qt 6 as:
#    set_property(TARGET fisheye_qt APPEND PROPERTY QT_ANDROID_PACKAGE_SOURCE_DIR
#                 ${CMAKE_CURRENT_SOURCE_DIR}/android)
# For more information, see https://doc.qt.io/qt-6/qt-add-executable.html#target-creation
else()
    if(ANDROID)
        add_library(fisheye_qt SHARED
            ${PROJECT_SOURCES}
        )
# Define properties for Android with Qt 5 after find_package() calls as:
#    set(ANDROID_PACKAGE_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/android")
    else()
        add_executable(fisheye_qt
            ${PROJECT_SOURCES}
        )
    endif()
endif()

target_link_libraries(fisheye_qt PRIVATE Qt${QT_VERSION_MAJOR}::Widgets)

# Qt for iOS sets MACOSX_BUNDLE_GUI_IDENTIFIER automatically since Qt 6.1.
# If you are developing for iOS or macOS you should consider setting an
# explicit, fixed bundle identifier manually though.
if(${QT_VERSION} VERSION_LESS 6.1.0)
  set(BUNDLE_ID_OPTION MACOSX_BUNDLE_GUI_IDENTIFIER com.example.fisheye_qt)
endif()
set_target_properties(fisheye_qt PROPERTIES
    ${BUNDLE_ID_OPTION}
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

include(GNUInstallDirs)
install(TARGETS fisheye_qt
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

if(QT_VERSION_MAJOR EQUAL 6)
    qt_finalize_executable(fisheye_qt)
endif()
