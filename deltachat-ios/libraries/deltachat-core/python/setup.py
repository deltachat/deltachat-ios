import setuptools


setuptools.setup(
    name='deltachat',
    version='0.1',
    description='Python bindings for deltachat-core using CFFI',
    author='Delta Chat contributors',
    setup_requires=['cffi>=1.0.0'],
    install_requires=['cffi>=1.0.0'],
    packages=setuptools.find_packages('src'),
    package_dir={'': 'src'},
    cffi_modules=['src/deltachat/_build.py:ffibuilder'],
    classifiers=[
        'Development Status :: 3 - Alpha',
        'Intended Audience :: Developers',
        'License :: OSI Approved :: GNU General Public License (GPL)',
        'Programming Language :: Python :: 3',
        'Topic :: Communications :: Email',
        'Topic :: Software Development :: Libraries',
    ],
)
