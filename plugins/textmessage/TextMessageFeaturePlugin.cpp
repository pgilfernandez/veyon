/*
 * TextMessageFeaturePlugin.cpp - implementation of TextMessageFeaturePlugin class
 *
 * Copyright (c) 2017-2025 Tobias Junghans <tobydox@veyon.io>
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
#include <QTextDocument>

#include "TextMessageFeaturePlugin.h"
#include "TextMessageDialog.h"
#include "FeatureWorkerManager.h"
#include "ComputerControlInterface.h"
#include "VeyonMasterInterface.h"
#include "VeyonServerInterface.h"
#include "VeyonCore.h"
#include "PlatformCoreFunctions.h"

namespace {

QString makeLargeFontHtml( const QString& originalText )
{
	static const auto styleStart = QStringLiteral( "<div style=\"font-size: 16px;\">" );
	static const auto styleEnd = QStringLiteral( "</div>" );

	QString plainText = originalText;

	const auto trimmedText = originalText.trimmed();
	if( trimmedText.startsWith( QLatin1Char( '<' ) ) )
	{
		QTextDocument doc;
		doc.setHtml( originalText );
		plainText = doc.toPlainText();
	}

	QString html;
	html.reserve( plainText.size() + 64 );
	html += styleStart;
	html += plainText.toHtmlEscaped();
	html += styleEnd;
	return html;
}

}


TextMessageFeaturePlugin::TextMessageFeaturePlugin( QObject* parent ) :
	QObject( parent ),
	m_textMessageFeature( Feature( QStringLiteral( "TextMessage" ),
								   Feature::Flag::Action | Feature::Flag::AllComponents,
								   Feature::Uid( "e75ae9c8-ac17-4d00-8f0d-019348346208" ),
								   Feature::Uid(),
								   tr( "Text message" ), {},
								   tr( "Use this function to send a text message to all "
									   "users e.g. to assign them new tasks." ),
								   QStringLiteral(":/textmessage/dialog-information.png") ) ),
	m_features( { m_textMessageFeature } )
{
}



const FeatureList &TextMessageFeaturePlugin::featureList() const
{
	return m_features;
}



bool TextMessageFeaturePlugin::controlFeature( Feature::Uid featureUid,
											  Operation operation,
											  const QVariantMap& arguments,
											  const ComputerControlInterfaceList& computerControlInterfaces )
{
	if( operation != Operation::Start )
	{
		return false;
	}

	if( featureUid == m_textMessageFeature.uid() )
	{
		const auto text = arguments.value( argToString(Argument::Text) ).toString();
		const auto icon = arguments.value( argToString(Argument::Icon) ).toInt();

		sendFeatureMessage( FeatureMessage{ featureUid, ShowTextMessage }
								.addArgument( Argument::Text, text )
								.addArgument( Argument::Icon, icon ), computerControlInterfaces );

		return true;
	}

	return false;
}



bool TextMessageFeaturePlugin::startFeature( VeyonMasterInterface& master, const Feature& feature,
											 const ComputerControlInterfaceList& computerControlInterfaces )
{
	if( feature.uid() != m_textMessageFeature.uid() )
	{
		return false;
	}

	QString textMessage;

	TextMessageDialog( textMessage, master.mainWindow() ).exec();

	if( textMessage.isEmpty() == false )
	{
		controlFeature( m_textMessageFeature.uid(), Operation::Start,
						{
							{ argToString(Argument::Text), textMessage },
							{ argToString(Argument::Icon), QMessageBox::Information }
						},
						computerControlInterfaces );
	}

	return true;
}




bool TextMessageFeaturePlugin::handleFeatureMessage( VeyonServerInterface& server,
													 const MessageContext& messageContext,
													 const FeatureMessage& message )
{
	Q_UNUSED(messageContext)

	if( m_textMessageFeature.uid() == message.featureUid() )
	{
		// forward message to worker
		server.featureWorkerManager().sendMessageToUnmanagedSessionWorker( message );

		return true;
	}

	return false;
}



bool TextMessageFeaturePlugin::handleFeatureMessage( VeyonWorkerInterface& worker, const FeatureMessage& message )
{
	Q_UNUSED(worker);

	qDebug() << "TextMessageFeaturePlugin::handleFeatureMessage called with featureUid:" << message.featureUid();
	qDebug() << "Expected featureUid:" << m_textMessageFeature.uid();

	if( message.featureUid() == m_textMessageFeature.uid() )
	{
		qDebug() << "Creating message box with text:" << message.argument( Argument::Text ).toString();

		const auto messageText = makeLargeFontHtml( message.argument( Argument::Text ).toString() );
		QMessageBox messageBox( static_cast<QMessageBox::Icon>( message.argument( Argument::Icon ).toInt() ),
								tr( "Message from teacher" ),
								QString() );
		messageBox.setTextFormat( Qt::RichText );
		messageBox.setTextInteractionFlags( Qt::TextBrowserInteraction | Qt::TextSelectableByKeyboard );
		messageBox.setText( messageText );

		qDebug() << "Showing message box...";
		messageBox.show();

		qDebug() << "Calling raiseWindow...";
		// Ensure the window is brought to the front on all platforms, especially macOS
		VeyonCore::platform().coreFunctions().raiseWindow( &messageBox, true );

		qDebug() << "Executing message box (modal)...";
		messageBox.exec();

		qDebug() << "Message box closed";

		return true;
	}

	qDebug() << "Feature UID did not match, returning false";
	return true;
}
