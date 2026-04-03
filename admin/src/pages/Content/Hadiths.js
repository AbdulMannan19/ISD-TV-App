import ContentManager from './ContentManager';

export default function Hadiths() {
  return (
    <ContentManager
      tableName="hadiths"
      title="Hadiths"
      subtitle="Manage daily hadiths mapped to the Hijri calendar"
      contentLabel="Hadith"
      hasSecondContent={true}
    />
  );
}
