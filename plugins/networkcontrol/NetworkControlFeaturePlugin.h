/*
 * NetworkControlFeaturePlugin.h - declaration of NetworkControlFeaturePlugin class
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

#pragma once

#include "Feature.h"
#include "FeatureProviderInterface.h"

class NetworkControlFeaturePlugin : public QObject,
		PluginInterface,
		FeatureProviderInterface
{
	Q_OBJECT
	Q_PLUGIN_METADATA(IID "io.veyon.Veyon.Plugins.NetworkControl")
	Q_INTERFACES(PluginInterface FeatureProviderInterface)
public:
	explicit NetworkControlFeaturePlugin( QObject* parent = nullptr );
	~NetworkControlFeaturePlugin() override = default;

	Plugin::Uid uid() const override
	{
		return Plugin::Uid{ QStringLiteral("a7b3c9d2-e4f5-4a6b-8c9d-0e1f2a3b4c5d") };
	}

	QVersionNumber version() const override
	{
		return QVersionNumber( 1, 0 );
	}

	QString name() const override
	{
		return QStringLiteral("NetworkControl");
	}

	QString description() const override
	{
		return tr( "Control network connectivity on client computers" );
	}

	QString vendor() const override
	{
		return QStringLiteral("Veyon Community");
	}

	QString copyright() const override
	{
		return QStringLiteral("Pablo");
	}

	const FeatureList& featureList() const override;

	bool controlFeature( Feature::Uid featureUid, Operation operation, const QVariantMap& arguments,
						const ComputerControlInterfaceList& computerControlInterfaces ) override;

	bool startFeature( VeyonMasterInterface& master, const Feature& feature,
					   const ComputerControlInterfaceList& computerControlInterfaces ) override;

	bool handleFeatureMessage( VeyonServerInterface& server,
							   const MessageContext& messageContext,
							   const FeatureMessage& message ) override;

	bool handleFeatureMessage( VeyonWorkerInterface& worker, const FeatureMessage& message ) override;

	bool isFeatureActive( VeyonServerInterface& server, Feature::Uid featureUid ) const override;

private:
	bool confirmFeatureExecution( const Feature& feature, bool all, QWidget* parent );

	void disableAllNetworkServices();
	void enableAllNetworkServices();
	QStringList getNetworkServices();
	bool setNetworkServiceEnabled( const QString& serviceName, bool enabled );

	const Feature m_disableNetworkFeature;
	const Feature m_enableNetworkFeature;
	const FeatureList m_features;
};
