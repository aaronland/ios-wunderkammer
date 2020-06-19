//
//  OEmbed.swift
//  shoebox
//
//  Created by asc on 6/10/20.
//  Copyright © 2020 Aaronland. All rights reserved.
//

/*
 
 {"version":"1.0","type":"photo","provider_name":"Cooper Hewitt","provider_url":"http:\/\/www.cooperhewitt.org\/","title":"Object ID #18704235","object_url":"https:\/\/collection.cooperhewitt.org\/objects\/18704235\/","object_id":"18704235","url":"https:\/\/images.collection.cooperhewitt.org\/92673_ea60e19b3a7f418c_z.jpg","height":640,"width":640,"thumbnail_url":"https:\/\/images.collection.cooperhewitt.org\/92673_ea60e19b3a7f418c_n.jpg","thumbnail_height":320,"thumbnail_width":640}
 
 */

/*
 
 {"version":"1.0","type":"photo","width":"800","height":"569","title":"photograph: San Francisco Airport, aerial view","url":"https:\/\/millsfield.sfomuseum.org\/media\/152\/785\/348\/1\/1527853481_Ui4MX67lVGt4uDdlMINgOe08QupC2H0Z_c.jpg","author_name":"SFO Museum","author_url":"https:\/\/millsfield.sfomuseum.org\/objects\/1511943457\/","provider_name":"SFO Museum","provider_url":"https:\/\/millsfield.sfomuseum.org\/","geotag:geojson_url":"https:\/\/millsfield.sfomuseum.org\/data\/1511943457\/","geotag:uri":"151\/194\/345\/7\/1511943457.geojson"}
 */

struct OEmbed: Codable {
    var version: String
    var type: String
    var provider_name: String
    var title: String
    var object_url: String?
    var object_id: String?
    var url: String
    var height: Int
    var width: Int
    var thumbnail_url: String
}
