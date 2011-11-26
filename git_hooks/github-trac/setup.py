from setuptools import find_packages, setup

# name can be any name.  This name will be used to create .egg file.
# name that is used in packages is the one that is used in the trac.ini file.
# use package name as entry_points

setup(
    name='GithubPlugin',
    version='0.4',
    author='Dav Glass',
    author_email='davglass@gmail.com',
    description = "Creates an entry point for a GitHub post-commit hook.",
    license = """Unknown Status""",
    url = "http://github.com/davglass/github-trac/tree/master",
    packages = find_packages(exclude=['*.tests*']),
	package_data={'github' : []},

    install_requires = [
        'simplejson>=2.0.5',
        'GitPython>=0.1.6',
    ],
    entry_points = {
        'trac.plugins': [
            'github = github',

        ]    
    }

)
