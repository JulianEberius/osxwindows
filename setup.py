from distutils.core import setup, Extension

setup(name = "osxwindows",
      version = "1.0",
      packages = ['osxwindows'],
      ext_modules = [Extension("osxwindows.osxaccessibility", ["osxwindows/osxaccessibility.m"],
        extra_link_args=['-framework', 'Carbon', '-framework', 'Cocoa']
      )])
