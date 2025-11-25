/*
 * NetworkControlFeaturePlugin.cpp - implementation of NetworkControlFeaturePlugin class
 *
 * Copyright (c) 2025 Pablo <pablo@example.com>
 *
 * This file is part of Veyon - https://veyon.io
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program (see COPYING); if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 *
 */

#include <QMessageBox>
#include <QProcess>
#include <QFile>
#include <QTextStream>

#include "ComputerControlInterface.h"
#include "NetworkControlFeaturePlugin.h"
#include "PlatformCoreFunctions.h"
#include "VeyonConfiguration.h"
#include "VeyonMasterInterface.h"
#include "VeyonServerInterface.h"


NetworkControlFeaturePlugin::NetworkControlFeaturePlugin( QObject* parent ) :
	QObject( parent ),
	m_disableNetworkFeature( QStringLiteral( "DisableNetwork" ),
					  Feature::Flag::Action | Feature::Flag::AllComponents,
					  Feature::Uid( "7a8b9c0d-1e2f-3a4b-5c6d-7e8f9a0b1c2d" ),
					  Feature::Uid(),
					  tr( "Disable Internet" ), {},
					  tr( "Click this button to disable internet connection on selected computers." ),
					  QStringLiteral(":/networkcontrol/network-disabled.png") ),
	m_enableNetworkFeature( QStringLiteral( "EnableNetwork" ),
					 Feature::Flag::Action | Feature::Flag::AllComponents,
					 Feature::Uid( "2d1c0b9a-8f7e-6d5c-4b3a-2f1e0d9c8b7a" ),
					 Feature::Uid(),
					 tr( "Enable Internet" ), {},
					 tr( "Click this button to enable internet connection on selected computers." ),
					 QStringLiteral(":/networkcontrol/network-enabled.png") ),
	m_features( { m_enableNetworkFeature, m_disableNetworkFeature } )
{
}


const FeatureList &NetworkControlFeaturePlugin::featureList() const
{
	return m_features;
}


bool NetworkControlFeaturePlugin::controlFeature( Feature::Uid featureUid,
											   Operation operation,
											   const QVariantMap& arguments,
											   const ComputerControlInterfaceList& computerControlInterfaces )
{
	Q_UNUSED(arguments)

	if( hasFeature( featureUid ) == false || operation != Operation::Start )
	{
		return false;
	}

	sendFeatureMessage( FeatureMessage{ featureUid, FeatureMessage::DefaultCommand }, computerControlInterfaces );

	return true;
}


bool NetworkControlFeaturePlugin::startFeature( VeyonMasterInterface& master, const Feature& feature,
											  const ComputerControlInterfaceList& computerControlInterfaces )
{
	const auto executeOnAllComputers =
		computerControlInterfaces.size() >= master.filteredComputerControlInterfaces().size();

	if (confirmFeatureExecution(feature, executeOnAllComputers, master.mainWindow()) == false)
	{
		return false;
	}

	return controlFeature( feature.uid(), Operation::Start, {}, computerControlInterfaces );
}


bool NetworkControlFeaturePlugin::handleFeatureMessage( VeyonServerInterface& server,
													  const MessageContext& messageContext,
													  const FeatureMessage& message )
{
	Q_UNUSED(messageContext)
	Q_UNUSED(server)

	if( message.featureUid() == m_disableNetworkFeature.uid() )
	{
		disableAllNetworkServices();
		return true;
	}
	else if( message.featureUid() == m_enableNetworkFeature.uid() )
	{
		enableAllNetworkServices();
		return true;
	}

	return false;
}


bool NetworkControlFeaturePlugin::handleFeatureMessage( VeyonWorkerInterface& worker, const FeatureMessage& message )
{
	Q_UNUSED(worker)
	Q_UNUSED(message)

	// No worker-side handling needed for network control
	return false;
}


bool NetworkControlFeaturePlugin::confirmFeatureExecution( const Feature& feature, bool all, QWidget* parent )
{
	if( VeyonCore::config().confirmUnsafeActions() == false )
	{
		return true;
	}

	QString featureName;
	if( feature == m_disableNetworkFeature )
	{
		featureName = tr( "disable internet connection on" );
	}
	else if( feature == m_enableNetworkFeature )
	{
		featureName = tr( "enable internet connection on" );
	}
	else
	{
		return true;
	}

	return QMessageBox::question( parent, tr( "Confirm network control" ),
								  all ? tr( "Do you really want to %1 <b>ALL</b> computers?" ).arg( featureName )
									  : tr( "Do you really want to %1 the selected computers?" ).arg( featureName ) ) ==
			QMessageBox::Yes;
}


void NetworkControlFeaturePlugin::disableAllNetworkServices()
{
	// Use helper script via sudo (configured in sudoers.d for no password)
	vInfo() << "Disabling internet access via helper script...";

	QProcess helperProcess;
	helperProcess.start( QStringLiteral("/usr/bin/sudo"),
	                    { QStringLiteral("/usr/local/bin/veyon-network-helper"), QStringLiteral("disable") } );

	if( !helperProcess.waitForFinished(10000) )
	{
		vWarning() << "Helper script timeout";
		return;
	}

	const auto output = QString::fromUtf8( helperProcess.readAllStandardOutput() );
	const auto errors = QString::fromUtf8( helperProcess.readAllStandardError() );

	vDebug() << "Helper output:" << output;
	if( !errors.isEmpty() )
	{
		vWarning() << "Helper errors:" << errors;
	}

	if( helperProcess.exitCode() == 0 )
	{
		vInfo() << "Internet access blocked successfully";
	}
	else
	{
		vWarning() << "Failed to block internet - exit code:" << helperProcess.exitCode();
	}
}


void NetworkControlFeaturePlugin::enableAllNetworkServices()
{
	// Use helper script via sudo (configured in sudoers.d for no password)
	vInfo() << "Enabling internet access via helper script...";

	QProcess helperProcess;
	helperProcess.start( QStringLiteral("/usr/bin/sudo"),
	                    { QStringLiteral("/usr/local/bin/veyon-network-helper"), QStringLiteral("enable") } );

	if( !helperProcess.waitForFinished(10000) )
	{
		vWarning() << "Helper script timeout";
		return;
	}

	const auto output = QString::fromUtf8( helperProcess.readAllStandardOutput() );
	const auto errors = QString::fromUtf8( helperProcess.readAllStandardError() );

	vDebug() << "Helper output:" << output;
	if( !errors.isEmpty() )
	{
		vWarning() << "Helper errors:" << errors;
	}

	if( helperProcess.exitCode() == 0 )
	{
		vInfo() << "Internet access restored successfully";
	}
	else
	{
		vWarning() << "Failed to restore internet - exit code:" << helperProcess.exitCode();
	}
}


QStringList NetworkControlFeaturePlugin::getNetworkServices()
{
	// Esta función ya no es necesaria en la implementación basada en rutas
	return {};
}


bool NetworkControlFeaturePlugin::setNetworkServiceEnabled( const QString& serviceName, bool enabled )
{
	Q_UNUSED(serviceName)
	Q_UNUSED(enabled)

	// Esta función ya no es necesaria en la implementación basada en rutas
	return true;
}
