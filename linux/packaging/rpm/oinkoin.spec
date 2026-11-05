# RPM spec for Oinkoin.
#
# scripts/build_linux_packages.sh stages the Flutter Linux bundle in
# %{_topdir}/BUILD/oinkoin and passes app_version/app_release from pubspec.yaml.
#
# Every path below is absolute on purpose: rpmbuild < 4.20 runs the scriptlets
# in %{_topdir}/BUILD, while rpm >= 4.20 (Ubuntu 26.04 runners) first creates an
# empty %{name}-%{version}-build directory and runs them there, so a relative
# path such as "oinkoin/*" would only work on the old rpmbuild.

%define _app_dir %{_topdir}/BUILD/oinkoin
%define _app_binary piggybank

Name:           oinkoin
Version:        %{app_version}
Release:        %{app_release}%{?dist}
Summary:        The expenses under your control.
Group:          Applications/Productivity
License:        MIT
URL:            https://github.com/emavgl/oinkoin
Requires:       sqlite-libs
Requires:       gtk3
Requires:       glib2
BuildArch:      x86_64

%description
Oinkoin is a money management app that helps you keep track of expenses,
income, budgets and recurrent transactions, with optional wallets, multiple
currencies and profiles.

%install
mkdir -p %{buildroot}%{_bindir}
mkdir -p %{buildroot}%{_datadir}/%{name}
mkdir -p %{buildroot}%{_datadir}/applications
mkdir -p %{buildroot}%{_datadir}/metainfo
mkdir -p %{buildroot}%{_datadir}/pixmaps
cp -r %{_app_dir}/* %{buildroot}%{_datadir}/%{name}
ln -s %{_datadir}/%{name}/%{_app_binary} %{buildroot}%{_bindir}/%{name}
install -m 0644 %{_app_dir}/oinkoin.desktop %{buildroot}%{_datadir}/applications/%{name}.desktop
install -m 0644 %{_app_dir}/oinkoin.png %{buildroot}%{_datadir}/pixmaps/%{name}.png

%post
update-mime-database %{_datadir}/mime &> /dev/null || :

%postun
update-mime-database %{_datadir}/mime &> /dev/null || :

%files
%defattr(-,root,root)
%{_bindir}/%{name}
%{_datadir}/%{name}
%{_datadir}/applications/%{name}.desktop
%{_datadir}/metainfo
%{_datadir}/pixmaps/%{name}.png
