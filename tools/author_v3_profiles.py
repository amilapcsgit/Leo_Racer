"""Authored reference dimensions and reviewed surface repairs; no package edits."""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[1]
p=ROOT/'assets/config/vehicle-presentation-v1.json'
data=json.loads(p.read_text(encoding='utf-8'))
rows=[
('byd_yangwang_u8',5.319,'https://yangwangqatar.com/u8/specifications/'),
('import_1968_volkswagen_beetle',4.070,'https://www.volkswagen-newsroom.com/en/vehicle-data-beetle-kaefer-1300-profile-19591'),
('import_1985_delorean_dmc_12_time_machine_bttf',4.267,'https://toyota-automobile-museum.jp/archives/car-database/detail.html?id=380'),
('import_1989_lamborghini_countach_25th_anniversary',4.140,'https://www.torino-museum.com/lineup/lamborghini-countach-anniversary25-2/'),
('import_1999_nissan_skyline_gtr_r34_c_west_2f2f',4.600,'https://www.nissan-global.com/EN/HERITAGE_COLLECTION/306_skyline_gt-r_m-spec_nur.html'),
('import_2004_porsche_carrera_gt',4.613,'https://newsroom.porsche.com/en_SG/2025/history/porsche-25-years-world-premiere-carrera-gt-40609.html'),
('import_2013_chevrolet_corvette_z06',4.460,'https://www.corvetteactioncenter.com/specs/c6/2013/2013_Corvette_Order_Guide.pdf'),
('import_2013_equipped_jeep_wrangler_unlimited_rubicon',4.751,'https://www.media.stellantis.com/uploads/fr/FR/2016/JEEP/TARIFS/Tarif_Public_Jeep_Wrangler_-_1er_septembre_2016.pdf'),
('import_2019_ford_mustang_rtr_spec5_10th_anniversary',4.7879,'https://media.ford.com/content/dam/fordmedia/North%20America/US/product/2019/mustang/2019-mustang-techspecs.pdf'),
('import_2020_jeep_gladiator',5.5372,'https://www.jeep.ca/en/gladiator/models'),
('import_2020_lbworks_toyota_supra_a90_ver_2',4.3815,'https://media.toyota.ca/en/releases/2019/a-legend-returns-2020-toyota-supra-makes-world-debut.html'),
('import_2022_mclaren_765lt',4.600,'https://cars.mclaren.com/uk_en/legacy/765lt'),
('import_chevrolet_cruze_ltz',4.597,'https://www.centuryu.com/uploads/1/4/4/6/144698822/2014_cruze.pdf'),
('import_dacia_duster_low_poly',4.341,'https://nd-mediagallery2-public-production.s3.amazonaws.com/ca22c43fe14ed3268b7adeb9d635da5c/duster_brochure_2018_november.pdf'),
('import_dacia_duster_widebody_highpoly',4.341,'https://nd-mediagallery2-public-production.s3.amazonaws.com/ca22c43fe14ed3268b7adeb9d635da5c/duster_brochure_2018_november.pdf'),
('import_fiat_500_x_outlaw',3.571,'https://www.fiat.com.au/fiat/500/technical-data'),
('import_hiluxbf',5.320,'https://newsroom.toyota.eu/the-all-new-toyota-hilux/'),
('import_mclaren_f1_1993_by_alex_ka',4.288,'https://www.mclarenofgreenwich.com/f1/'),
('import_toyota_kijang_innova_zenix_2023_highpoly',4.755,'https://www.toyota.astra.co.id/sites/default/files/2023-09/brochures/catalog_all_new_kijang_innova_zenix_hybrid_ev_1_0.pdf'),
('import_toyota_landcruiser_v8_2022',4.980,'https://www.toyota.com.au/-/media/toyota/main-site/vehicle-hubs/lc300/files/20260505-lc300_spec_table_gto009725.pdf'),
('import_1937_auto_union_type_c_streamliner',5.800,'https://www.traumautoarchiv.de/html/4019.html'),
('import_pininfarina_h2_speed',4.730,'https://www.netcarshow.com/pininfarina/2019-h2_speed/'),
]
for key,length,source in rows:data[key]={'length':length,'source':source,'note':'Uniform length correction; retain authored proportions and aftermarket bodywork. Reference generation may differ where asset year is ambiguous.'}
# MP4-25 is a stylized authored derivative, not a dimensionally exact scanned car.
data['mclaren']={'length':4.365,'source':'Authored MP4-25 derivative: fleet-audit.json measured model bounds','note':'Retain documented authored competition size; no invented homologation dimensions.'}
p.write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')
audit=json.loads((ROOT/'build/distinct/v3-audit/fleet-audit.json').read_text(encoding='utf-8'))
repairs={
 'race_bus':{'glass':['glass']},
 'cyberpunk':{'glass':['GL_basic_Glass_material']},
 'import_future_car':{'glass':['glass']},
 'import_toyota_landcruiser_v8_2022':{'paint':['White']},
 'import_chevrolet_cruze_ltz':{'glass':['cruze_window','cruze_glass']},
}
manifest={}
for car in audit:
    key=car['id'];roles=repairs.get(key,{})
    targets=[]
    for material in car['materials']:
        for role,names in roles.items():
            if material['name'] in names:targets.append({'node':material['node'],'surface':material['surface'],'material':material['name'],'role':role})
    manifest[key]={'decision':'repair' if targets else 'preserve','reason':'Reviewed matte body or opaque/metallic/frosted window surface' if targets else 'Preserve authored PBR/textured or intentional stylized surfaces','targets':targets}
(ROOT/'assets/config/vehicle-material-repairs-v1.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
print('Authored',len(data),'dimension references and',len(manifest),'material decisions;',sum(len(v['targets']) for v in manifest.values()),'explicit surface repairs')
